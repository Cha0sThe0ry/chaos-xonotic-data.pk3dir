#include "mapvoting.qh"

#include <common/constants.qh>
#include <common/mapinfo.qh>
#include <common/net_linked.qh>
#include <common/playerstats.qh>
#include <common/state.qh>
#include <common/stats.qh>
#include <common/util.qh>
#include <common/weapons/_all.qh>
#include <server/client.qh>
#include <server/command/cmd.qh>
#include <server/command/getreplies.qh>
#include <server/gamelog.qh>
#include <server/world.qh>

// definitions

float mapvote_nextthink;
float mapvote_reduce_time;
int mapvote_reduce_count;
float mapvote_timeout;
const int MAPVOTE_SCREENSHOT_DIRS_COUNT = 4;
string mapvote_screenshot_dirs[MAPVOTE_SCREENSHOT_DIRS_COUNT];
int mapvote_screenshot_dirs_count;

int mapvote_count;
int mapvote_count_real;
string mapvote_maps[MAPVOTE_COUNT];
int mapvote_maps_screenshot_dir[MAPVOTE_COUNT];
string mapvote_maps_pakfile[MAPVOTE_COUNT];
bool mapvote_maps_suggested[MAPVOTE_COUNT];
string mapvote_suggestions[MAPVOTE_COUNT];
int mapvote_suggestion_ptr;
int mapvote_voters;
int mapvote_selections[MAPVOTE_COUNT]; // number of votes
int mapvote_maps_flags[MAPVOTE_COUNT];
int mapvote_ranked[MAPVOTE_COUNT]; // maps ranked by most votes, first = most
float mapvote_rng[MAPVOTE_COUNT]; // random() value for each map to determine tiebreakers
/* NOTE: mapvote_rng array can be replaced with a randomly selected index of the tie-winner.
 * If the tie-winner isn't included in the tie, choose the nearest index that is included.
 * This would use less storage but isn't truly random and can sometimes be predictable.
 */
bool mapvote_run;
int mapvote_detail;
bool mapvote_abstain;
.int mapvote;

entity mapvote_ent;

/**
 * Returns the gamtype ID from its name, if type_name isn't a real gametype it
 * checks for sv_vote_gametype_(type_name)_type
 */
Gametype GameTypeVote_Type_FromString(string type_name)
{
	Gametype type = MapInfo_Type_FromString(type_name, false, false);
	if (type == NULL)
		type = MapInfo_Type_FromString(cvar_string(
			strcat("sv_vote_gametype_",type_name,"_type")), false, false);
	return type;
}

int GameTypeVote_AvailabilityStatus(string type_name)
{
	int flag = GTV_FORBIDDEN;

	Gametype type = MapInfo_Type_FromString(type_name, false, false);
	if ( type == NULL )
	{
		type = MapInfo_Type_FromString(cvar_string(
			strcat("sv_vote_gametype_",type_name,"_type")), false, false);
		flag |= GTV_CUSTOM;
	}

	if( type == NULL )
		return flag;

	if ( get_nextmap() != "" )
	{
		if ( !MapInfo_Get_ByName(get_nextmap(), false, NULL) )
			return flag;
		if (!(MapInfo_Map_supportedGametypes & type.gametype_flags))
			return flag;
	}

	return flag | GTV_AVAILABLE;
}

vector GameTypeVote_GetMask()
{
	int n, j;
	vector gametype_mask;
	n = tokenizebyseparator(autocvar_sv_vote_gametype_options, " ");
	n = min(MAPVOTE_COUNT, n);
	gametype_mask = '0 0 0';
	for(j = 0; j < n; ++j)
		gametype_mask |= GameTypeVote_Type_FromString(argv(j)).gametype_flags;

	if (gametype_mask == '0 0 0')
		gametype_mask |= MapInfo_CurrentGametype().gametype_flags;

	return gametype_mask;
}

string GameTypeVote_MapInfo_FixName(string m)
{
	if ( autocvar_sv_vote_gametype )
	{
		MapInfo_Enumerate();
		_MapInfo_FilterGametype(GameTypeVote_GetMask(), 0, MapInfo_RequiredFlags(), MapInfo_ForbiddenFlags(), 0);
	}
	return MapInfo_FixName(m);
}

void MapVote_ClearAllVotes()
{
	FOREACH_CLIENT(true, { it.mapvote = 0; });
}

void MapVote_UnzoneStrings()
{
	for(int j = 0; j < mapvote_count; ++j)
	{
		strfree(mapvote_maps[j]);
		strfree(mapvote_maps_pakfile[j]);
	}
}

string MapVote_Suggest(entity this, string m)
{
	int i;
	if(m == "")
		return "That's not how to use this command.";
	if(!autocvar_g_maplist_votable_suggestions)
		return "Suggestions are not accepted on this server.";
	if(mapvote_initialized)
	if(!gametypevote)
		return "Can't suggest - voting is already in progress!";
	m = GameTypeVote_MapInfo_FixName(m);
	if (!m)
		return "The map you suggested is not available on this server.";
	if(!autocvar_g_maplist_votable_suggestions_override_mostrecent)
		if(Map_IsRecent(m))
			return "This server does not allow for recent maps to be played again. Please be patient for some rounds.";

	if (!autocvar_sv_vote_gametype)
	if(!MapInfo_CheckMap(m))
		return "The map you suggested does not support the current game mode.";
	for(i = 0; i < mapvote_suggestion_ptr; ++i)
		if(mapvote_suggestions[i] == m)
			return "This map was already suggested.";
	if(mapvote_suggestion_ptr >= MAPVOTE_COUNT)
	{
		i = floor(random() * mapvote_suggestion_ptr);
	}
	else
	{
		i = mapvote_suggestion_ptr;
		++mapvote_suggestion_ptr;
	}
	if(mapvote_suggestions[i] != "")
		strunzone(mapvote_suggestions[i]);
	mapvote_suggestions[i] = strzone(m);
	if(autocvar_sv_eventlog)
		GameLogEcho(strcat(":vote:suggested:", m, ":", ftos(this.playerid)));
	return strcat("Suggestion of ", m, " accepted.");
}

void MapVote_AddVotable(string nextMap, bool isSuggestion)
{
	int j, i, o;
	string pakfile, mapfile;

	if(nextMap == "")
		return;
	for(j = 0; j < mapvote_count; ++j)
		if(mapvote_maps[j] == nextMap)
			return;
	// suggestions might be no longer valid/allowed after gametype switch!
	if(isSuggestion)
		if(!MapInfo_CheckMap(nextMap))
			return;
	mapvote_maps[mapvote_count] = strzone(nextMap);
	mapvote_maps_suggested[mapvote_count] = isSuggestion;
	mapvote_rng[mapvote_count] = random();

	pakfile = string_null;
	for(i = 0; i < mapvote_screenshot_dirs_count; ++i)
	{
		mapfile = strcat(mapvote_screenshot_dirs[i], "/", nextMap);
		pakfile = whichpack(strcat(mapfile, ".tga"));
		if(pakfile == "")
			pakfile = whichpack(strcat(mapfile, ".jpg"));
		if(pakfile == "")
			pakfile = whichpack(strcat(mapfile, ".png"));
		if(pakfile != "")
			break;
	}
	if(i >= mapvote_screenshot_dirs_count)
		i = 0; // FIXME maybe network this error case, as that means there is no mapshot on the server?
	for(o = strstrofs(pakfile, "/", 0)+1; o > 0; o = strstrofs(pakfile, "/", 0)+1)
		pakfile = substring(pakfile, o, -1);

	mapvote_maps_screenshot_dir[mapvote_count] = i;
	mapvote_maps_pakfile[mapvote_count] = strzone(pakfile);
	mapvote_maps_flags[mapvote_count] = GTV_AVAILABLE;

	++mapvote_count;
}

void MapVote_AddVotableMaps(int nmax, int smax)
{
	int available_maps = Maplist_Init();
	int max_attempts = available_maps;
	if (available_maps >= 2)
		max_attempts = min(available_maps * 5, 100);

	if (smax && mapvote_suggestion_ptr)
		for(int i = 0; i < max_attempts && mapvote_count < smax; ++i)
			MapVote_AddVotable(mapvote_suggestions[floor(random() * mapvote_suggestion_ptr)], true);

	for (int i = 0; i < max_attempts && mapvote_count < nmax; ++i)
		MapVote_AddVotable(GetNextMap(), false);

	mapvote_ranked[0] = 0;

	Maplist_Close();
}

string voted_gametype_string;
Gametype voted_gametype;
Gametype match_gametype;
int current_gametype_index;
void MapVote_Init()
{
	int nmax, smax;

	MapVote_ClearAllVotes();
	MapVote_UnzoneStrings();

	mapvote_count = 0;
	mapvote_detail = autocvar_g_maplist_votable_detail;
	mapvote_abstain = autocvar_g_maplist_votable_abstain;
	current_gametype_index = -1;

	if(mapvote_abstain)
		nmax = min(MAPVOTE_COUNT - 1, autocvar_g_maplist_votable);
	else
		nmax = min(MAPVOTE_COUNT, autocvar_g_maplist_votable);
	smax = min3(nmax, autocvar_g_maplist_votable_suggestions, mapvote_suggestion_ptr);

	// we need this for AddVotable, as that cycles through the screenshot dirs
	mapvote_screenshot_dirs_count = tokenize_console(autocvar_g_maplist_votable_screenshot_dir);
	if(mapvote_screenshot_dirs_count == 0)
		mapvote_screenshot_dirs_count = tokenize_console("maps levelshots");
	mapvote_screenshot_dirs_count = min(mapvote_screenshot_dirs_count, MAPVOTE_SCREENSHOT_DIRS_COUNT);
	for(int i = 0; i < mapvote_screenshot_dirs_count; ++i)
		mapvote_screenshot_dirs[i] = strzone(argv(i));

	MapVote_AddVotableMaps(nmax, smax);

	mapvote_count_real = mapvote_count;
	if(mapvote_abstain)
		MapVote_AddVotable("don't care", false);

	//dprint("mapvote count is ", ftos(mapvote_count), "\n");

	mapvote_reduce_time = time + autocvar_g_maplist_votable_reduce_time;
	mapvote_reduce_count = autocvar_g_maplist_votable_reduce_count;
	mapvote_timeout = time + autocvar_g_maplist_votable_timeout;
	if(mapvote_count_real < 3 || mapvote_reduce_time <= time)
		mapvote_reduce_time = 0;

	MapVote_Spawn();

	// If match_gametype is set it means voted_gametype has just been applied (on game type vote end).
	// In this case apply back match_gametype here so that the "restart" command, if called,
	// properly restarts the map applying the current game type.
	// Applying voted_gametype before map vote start is needed to properly initialize map vote.
	string gametype_custom_string = "";
	if (gametype_custom_enabled)
		gametype_custom_string = loaded_gametype_custom_string;
	if (match_gametype)
		GameTypeVote_SetGametype(match_gametype, gametype_custom_string, true);
}

void MapVote_SendPicture(entity to, int id)
{
	msg_entity = to;
	WriteHeader(MSG_ONE, TE_CSQC_PICTURE);
	WriteByte(MSG_ONE, id);
	WritePicture(MSG_ONE, strcat(mapvote_screenshot_dirs[mapvote_maps_screenshot_dir[id]], "/", mapvote_maps[id]), 3072);
}


void MapVote_WriteMask()
{
	if ( mapvote_count < 24 )
	{
		int mask = 0;
		for(int j = 0; j < mapvote_count; ++j)
		{
			if(mapvote_maps_flags[j] & GTV_AVAILABLE)
				mask |= BIT(j);
		}

		if(mapvote_count < 8)
			WriteByte(MSG_ENTITY, mask);
		else if (mapvote_count < 16)
			WriteShort(MSG_ENTITY,mask);
		else
			WriteLong(MSG_ENTITY, mask);
	}
	else
	{
		for (int j = 0; j < mapvote_count; ++j)
			WriteByte(MSG_ENTITY, mapvote_maps_flags[j]);
	}
}

/*
 * Sends a single map vote option to the client
 */
void MapVote_SendOption(int i)
{
	// abstain
	if(mapvote_abstain && i == mapvote_count - 1)
	{
		WriteString(MSG_ENTITY, ""); // abstain needs no text
		WriteString(MSG_ENTITY, ""); // abstain needs no pack
		WriteByte(MSG_ENTITY, 0); // abstain needs no screenshot dir
	}
	else
	{
		WriteString(MSG_ENTITY, mapvote_maps[i]);
		WriteString(MSG_ENTITY, mapvote_maps_pakfile[i]);
		WriteByte(MSG_ENTITY, mapvote_maps_screenshot_dir[i]);
	}
}

/*
 * Sends a single gametype vote option to the client
 */
void GameTypeVote_SendOption(int i)
{
	// abstain
	if(mapvote_abstain && i == mapvote_count - 1)
	{
		WriteString(MSG_ENTITY, ""); // abstain needs no text
		WriteByte(MSG_ENTITY, GTV_AVAILABLE);
	}
	else
	{
		string type_name = mapvote_maps[i];
		WriteString(MSG_ENTITY, type_name);
		WriteByte(MSG_ENTITY, mapvote_maps_flags[i]);
		if ( mapvote_maps_flags[i] & GTV_CUSTOM )
		{
			WriteString(MSG_ENTITY, cvar_string(
				strcat("sv_vote_gametype_",type_name,"_name")));
			WriteString(MSG_ENTITY, cvar_string(
				strcat("sv_vote_gametype_",type_name,"_description")));
			WriteString(MSG_ENTITY, cvar_string(
				strcat("sv_vote_gametype_",type_name,"_type")));
		}
	}
}

int mapvote_winner;
float mapvote_winner_time;
bool MapVote_SendEntity(entity this, entity to, int sf)
{
	int i;

	if(sf & 1)
		sf &= ~2; // if we send 1, we don't need to also send 2

	if (!mapvote_winner_time)
		sf &= ~8; // no winner yet

	WriteHeader(MSG_ENTITY, ENT_CLIENT_MAPVOTE);
	WriteByte(MSG_ENTITY, sf);

	if(sf & 1)
	{
		// flag 1 == initialization
		for(i = 0; i < mapvote_screenshot_dirs_count; ++i)
			WriteString(MSG_ENTITY, mapvote_screenshot_dirs[i]);
		WriteString(MSG_ENTITY, "");
		WriteByte(MSG_ENTITY, mapvote_count);
		WriteByte(MSG_ENTITY, mapvote_abstain);
		WriteByte(MSG_ENTITY, mapvote_detail);
		WriteCoord(MSG_ENTITY, mapvote_timeout);

		if ( gametypevote )
		{
			// gametype vote
			WriteByte(MSG_ENTITY, BIT(0)); // gametypevote_flags
			WriteString(MSG_ENTITY, get_nextmap());
		}
		else if ( autocvar_sv_vote_gametype )
		{
			// map vote but gametype has been chosen via voting screen
			WriteByte(MSG_ENTITY, BIT(1)); // gametypevote_flags
			string voted_gametype_name;
			if (voted_gametype_string == MapInfo_Type_ToString(voted_gametype))
				voted_gametype_name = MapInfo_Type_ToText(voted_gametype);
			else
				voted_gametype_name = cvar_string(strcat("sv_vote_gametype_", voted_gametype_string, "_name"));
			WriteString(MSG_ENTITY, voted_gametype_name);
		}
		else
			WriteByte(MSG_ENTITY, 0); // map vote

		MapVote_WriteMask();

		// Send data for the vote options
		for(i = 0; i < mapvote_count; ++i)
		{
			if(gametypevote)
				GameTypeVote_SendOption(i);
			else
				MapVote_SendOption(i);
		}
	}

	if(sf & 2) // flag 2 == update of mask
		MapVote_WriteMask();

	if(sf & 4)
	{
		if(mapvote_detail)
		{
			for(i = 0; i < mapvote_count; ++i)
				if ( mapvote_maps_flags[i] & GTV_AVAILABLE )
					WriteByte(MSG_ENTITY, mapvote_selections[i]);

			if(mapvote_detail == 2) // tell the client who the tie winner will be
				WriteChar(MSG_ENTITY, mapvote_ranked[0]);
			else if(mapvote_selections[mapvote_ranked[0]] == 0) // no votes yet, don't draw a winner (-1)
				WriteChar(MSG_ENTITY, -1);
			else // figure out winners yourself (-2)
				WriteChar(MSG_ENTITY, -2);
		}

		WriteByte(MSG_ENTITY, to.mapvote);
	}

	if(sf & 8)
		WriteByte(MSG_ENTITY, mapvote_winner + 1);

	return true;
}

void MapVote_Spawn()
{
	Net_LinkEntity(mapvote_ent = new(mapvote_ent), false, 0, MapVote_SendEntity);
}

void MapVote_TouchMask()
{
	mapvote_ent.SendFlags |= 2;
}

void MapVote_TouchVotes(entity voter)
{
	mapvote_ent.SendFlags |= 4;
}

void MapVote_Winner(int mappos)
{
	mapvote_ent.SendFlags |= 8;
	mapvote_winner_time = time;
	mapvote_winner = mappos;
}

bool MapVote_Finished(int mappos)
{
	if(alreadychangedlevel)
		return false;

	string result;
	int i;
	int didntvote;

	if(autocvar_sv_eventlog)
	{
		result = strcat(":vote:finished:", mapvote_maps[mappos]);
		result = strcat(result, ":", ftos(mapvote_selections[mappos]), "::");
		didntvote = mapvote_voters;
		for(i = 0; i < mapvote_count; ++i)
			if(mapvote_maps_flags[i] & GTV_AVAILABLE )
			{
				didntvote -= mapvote_selections[i];
				if(i != mappos)
				{
					result = strcat(result, ":", mapvote_maps[i]);
					result = strcat(result, ":", ftos(mapvote_selections[i]));
				}
			}
		result = strcat(result, ":didn't vote:", ftos(didntvote));

		GameLogEcho(result);
		if(mapvote_maps_suggested[mappos])
			GameLogEcho(strcat(":vote:suggestion_accepted:", mapvote_maps[mappos]));
	}

	FOREACH_CLIENT(IS_REAL_CLIENT(it), { FixClientCvars(it); });

	if(gametypevote)
	{
		if ( GameTypeVote_Finished(mappos) )
		{
			gametypevote = false;
			if(get_nextmap() != "")
			{
				Map_Goto_SetStr(get_nextmap());
				Map_Goto(0);
				alreadychangedlevel = true;
				strfree(voted_gametype_string);
				return true;
			}
			else
				MapVote_Init();
		}
		return false;
	}

	MapVote_Winner(mappos);
	alreadychangedlevel = true;

	return true;
}

void mapvote_ranked_swap(int i, int j, entity pass)
{
	TC(int, i); TC(int, j);
	const int tmp = mapvote_ranked[i];
	mapvote_ranked[i] = mapvote_ranked[j];
	mapvote_ranked[j] = tmp;
}
int mapvote_ranked_cmp(int i, int j, entity pass)
{
	TC(int, i); TC(int, j);
	const int ri = mapvote_ranked[i];
	const int rj = mapvote_ranked[j];
	const bool avail_i = mapvote_maps_flags[ri] & GTV_AVAILABLE;
	const bool avail_j = mapvote_maps_flags[rj] & GTV_AVAILABLE;
	if (avail_j && !avail_i) // i isn't votable, just move it to the end
		return 1;
	if (avail_i && !avail_j) // j isn't votable, just move it to the end
		return -1;
	if (!avail_i && !avail_j)
		return 0;

	const int votes_i = mapvote_selections[ri];
	const int votes_j = mapvote_selections[rj];
	if (votes_i <= 0 && rj == current_gametype_index) // j is the current and should be used
		return 1;
	if (votes_j <= 0 && ri == current_gametype_index) // i is the current and should be used
		return -1;
	if (votes_i == votes_j) // randomly choose which goes first
		return (mapvote_rng[rj] > mapvote_rng[ri]) ? 1 : -1;
	return votes_j - votes_i; // descending order
}

void MapVote_CheckRules_count()
{
	int i;
	for (i = 0; i < mapvote_count; ++i) // reset all votes
		if (mapvote_maps_flags[i] & GTV_AVAILABLE)
		{
			//dprint("Map ", ftos(i), ": "); dprint(mapvote_maps[i], "\n");
			mapvote_selections[i] = 0;
		}

	mapvote_voters = 0;
	FOREACH_CLIENT(IS_REAL_CLIENT(it), { // add votes
		++mapvote_voters;
		if (it.mapvote)
		{
			int idx = it.mapvote - 1;
			//dprint("Player ", it.netname, " vote = ", ftos(idx), "\n");
			++mapvote_selections[idx];
		}
	});

	for (i = 0; i < mapvote_count; ++i) // sort by most votes, for any ties choose randomly
		mapvote_ranked[i] = i; // populate up to mapvote_count, only bother sorting up to mapvote_count_real
	heapsort(mapvote_count_real, mapvote_ranked_swap, mapvote_ranked_cmp, NULL);
}

bool MapVote_CheckRules_decide()
{
	if (mapvote_count_real == 1)
		return MapVote_Finished(0);

	int mapvote_voters_real = mapvote_voters;
	if (mapvote_abstain)
		mapvote_voters_real -= mapvote_selections[mapvote_count - 1]; // excluding abstainers

	//dprint("1st place index: ", ftos(mapvote_ranked[0]), "\n");
	//dprint("1st place votes: ", ftos(mapvote_selections[mapvote_ranked[0]]), "\n");
	//dprint("2nd place index: ", ftos(mapvote_ranked[1]), "\n");
	//dprint("2nd place votes: ", ftos(mapvote_selections[mapvote_ranked[1]]), "\n");

	// these are used to check whether even if everyone else all voted for one map,
	// ... it wouldn't be enough to push it into the top `reduce_count` maps
	// i.e. reducing can start early
	int votes_recent = mapvote_selections[mapvote_ranked[0]];
	int votes_running_total = votes_recent;

	if (time > mapvote_timeout
	|| (mapvote_voters_real - votes_running_total) < votes_recent
	||  mapvote_voters_real == 0) // all abstained
		return MapVote_Finished(mapvote_ranked[0]); // choose best

	// if mapvote_reduce_count is >= 2, we reduce to the top `reduce_count`, keeping exactly that many
	// if it's < 2, we keep all maps that received at least 1 vote, as long as there's at least 2
	int ri, i;
	const bool keep_exactly = (mapvote_reduce_count >= 2);
#define REDUCE_REMOVE_THIS(idx) (keep_exactly \
	? (idx >= mapvote_reduce_count) \
	: (mapvote_selections[mapvote_ranked[idx]] <= 0))
	for (ri = 1; ri < mapvote_count; ++ri)
	{
		i = mapvote_ranked[ri];
		if (REDUCE_REMOVE_THIS(ri))
			break;
		votes_recent = mapvote_selections[i];
		votes_running_total += votes_recent;
	}

	if (mapvote_reduce_time)
	if ((time > mapvote_reduce_time && (keep_exactly || ri >= 2))
	|| (mapvote_voters_real - votes_running_total) < votes_recent)
	{
		MapVote_TouchMask();
		mapvote_reduce_time = 0;
		string result = ":vote:reduce";
		int didnt_vote = mapvote_voters;
		bool remove = false;
		for (ri = 0; ri < mapvote_count; ++ri)
		{
			i = mapvote_ranked[ri];
			didnt_vote -= mapvote_selections[i];
			result = strcat(result, ":", mapvote_maps[i]);
			result = strcat(result, ":", ftos(mapvote_selections[i]));
			if (!remove && REDUCE_REMOVE_THIS(ri))
			{
				result = strcat(result, "::"); // separator between maps kept and maps removed
				remove = true;
			}
			if (remove && i < mapvote_count_real)
				mapvote_maps_flags[i] &= ~GTV_AVAILABLE; // make it not votable
		}
		result = strcat(result, ":didn't vote:", ftos(didnt_vote));
		if (autocvar_sv_eventlog)
			GameLogEcho(result);
	}
#undef REDUCE_REMOVE_THIS

	return false;
}

void MapVote_Tick()
{
	MapVote_CheckRules_count();
	if(MapVote_CheckRules_decide())
		return;

	int totalvotes = 0;
	FOREACH_CLIENT(true, {
		if(!IS_REAL_CLIENT(it))
		{
			// apply the same special health value to bots too for consistency's sake
			if(GetResource(it, RES_HEALTH) != 2342)
				SetResourceExplicit(it, RES_HEALTH, 2342);
			continue;
		}
		// hide scoreboard again
		if(GetResource(it, RES_HEALTH) != 2342)
		{
			SetResourceExplicit(it, RES_HEALTH, 2342); // health in the voting phase
			CS(it).impulse = 0;

			msg_entity = it;
			WriteByte(MSG_ONE, SVC_FINALE);
			WriteString(MSG_ONE, "");
		}

		// clear possibly invalid votes
		if ( !(mapvote_maps_flags[it.mapvote-1] & GTV_AVAILABLE) )
			it.mapvote = 0;
		// use impulses as new vote
		if(CS(it).impulse >= 1 && CS(it).impulse <= mapvote_count)
			if( mapvote_maps_flags[CS(it).impulse - 1] & GTV_AVAILABLE )
			{
				it.mapvote = CS(it).impulse;
				MapVote_TouchVotes(it);
			}
		CS(it).impulse = 0;

		if(it.mapvote)
			++totalvotes;
	});

	MapVote_CheckRules_count(); // just count
}

void MapVote_Start()
{
	// if mapvote is already running, don't do this initialization again
	if(mapvote_run) { return; }

	// don't start mapvote until after playerstats gamereport is sent
	if(PlayerStats_GameReport_DelayMapVote) { return; }

	MapInfo_Enumerate();
	if(MapInfo_FilterGametype(MapInfo_CurrentGametype(), MapInfo_CurrentFeatures(), MapInfo_RequiredFlags(), MapInfo_ForbiddenFlags(), 1))
		mapvote_run = true;
}

void MapVote_Think()
{
	if(!mapvote_run)
		return;

	if (mapvote_winner_time)
	{
		if (time > mapvote_winner_time + 1)
		{
			if (voted_gametype)
			{
				// clear match_gametype so that GameTypeVote_SetGametype
				// prints the game type switch message
				match_gametype = NULL;
				GameTypeVote_SetGametype(voted_gametype, voted_gametype_string, true);
			}

			Map_Goto_SetStr(mapvote_maps[mapvote_winner]);
			Map_Goto(0);
			strfree(voted_gametype_string);
		}
		return;
	}

	if(alreadychangedlevel)
		return;

	if(time < mapvote_nextthink)
		return;
	//dprint("tick\n");

	mapvote_nextthink = time + 0.5;
	if (mapvote_nextthink > mapvote_timeout - 0.1) // make sure there's no delay when map vote times out
		mapvote_nextthink = mapvote_timeout + 0.001;

	if(!mapvote_initialized)
	{
		if(autocvar_rescan_pending == 1)
		{
			cvar_set("rescan_pending", "2");
			localcmd("fs_rescan\nrescan_pending 3\n");
			return;
		}
		else if(autocvar_rescan_pending == 2)
		{
			return;
		}
		else if(autocvar_rescan_pending == 3)
		{
			// now build missing mapinfo files
			if(!MapInfo_FilterGametype(MapInfo_CurrentGametype(), MapInfo_CurrentFeatures(), MapInfo_RequiredFlags(), MapInfo_ForbiddenFlags(), 1))
				return;

			// we're done, start the timer
			cvar_set("rescan_pending", "0");
		}

		mapvote_initialized = true;
		if(DoNextMapOverride(0))
			return;
		if(!autocvar_g_maplist_votable || player_count <= 0)
		{
			GotoNextMap(0);
			return;
		}

		if(autocvar_sv_vote_gametype) { GameTypeVote_Start(); }
		else if(get_nextmap() == "") { MapVote_Init(); }
	}

	MapVote_Tick();
}

// if gametype_string is "" then gametype_string is inferred from Gametype type
// otherwise gametype_string is the string (short name) of a custom gametype
bool GameTypeVote_SetGametype(Gametype type, string gametype_string, bool call_hooks)
{
	if (gametype_string == "")
		gametype_string = MapInfo_Type_ToString(type);
	if (!call_hooks)
	{
		// custom gametype is disabled because gametype hooks can't be executed
		gametype_custom_enabled = false;
	}
	else
	{
		gametype_custom_enabled = (gametype_string != MapInfo_Type_ToString(type));

		localcmd("sv_vote_gametype_hook_all\n");
		localcmd("sv_vote_gametype_hook_", gametype_string, "\n");
	}

	if (MapInfo_CurrentGametype() == type)
		return true;

	Gametype tsave = MapInfo_CurrentGametype();

	MapInfo_SwitchGameType(type);

	MapInfo_Enumerate();
	MapInfo_FilterGametype(type, MapInfo_CurrentFeatures(), MapInfo_RequiredFlags(), MapInfo_ForbiddenFlags(), 0);
	if(MapInfo_count > 0)
	{
		// update lsmaps in case the gametype changed, this way people can easily list maps for it
		if(lsmaps_reply != "") { strunzone(lsmaps_reply); }
		lsmaps_reply = strzone(getlsmaps());

		if (!match_gametype) // don't show this msg if we are temporarily switching game type
			bprint("Game type successfully switched to ", MapInfo_Type_ToString(type), "\n");
	}
	else
	{
		bprint("Cannot use this game type: no map for it found\n");
		MapInfo_SwitchGameType(tsave);
		MapInfo_FilterGametype(MapInfo_CurrentGametype(), MapInfo_CurrentFeatures(), MapInfo_RequiredFlags(), MapInfo_ForbiddenFlags(), 0);
		return false;
	}

	bool doreset = autocvar_sv_vote_gametype_maplist_reset;
	string gvmaplist = strcat("sv_vote_gametype_", gametype_string, "_maplist");
	if(cvar_type(gvmaplist) & CVAR_TYPEFLAG_EXISTS)
	{
		// force a reset if the provided list is empty
		if(cvar_string(gvmaplist) == "")
			doreset = true;
		else
			cvar_set("g_maplist", cvar_string(gvmaplist));
	}
	if(doreset)
		cvar_set("g_maplist", MapInfo_ListAllowedMaps(type, MapInfo_RequiredFlags(), MapInfo_ForbiddenFlags()) );

	return true;
}

bool gametypevote_finished;
bool GameTypeVote_Finished(int pos)
{
	if(!gametypevote || gametypevote_finished)
		return false;

	match_gametype = MapInfo_CurrentGametype();
	voted_gametype = GameTypeVote_Type_FromString(mapvote_maps[pos]);
	strcpy(voted_gametype_string, mapvote_maps[pos]);

	GameTypeVote_SetGametype(voted_gametype, voted_gametype_string, true);

	// save to a cvar so it can be applied back when gametype is temporary
	// changed on gametype vote end of the next game
	if (mapvote_maps_flags[pos] & GTV_CUSTOM)
		cvar_set("_sv_vote_gametype_custom", voted_gametype_string);

	gametypevote_finished = true;

	return true;
}

bool GameTypeVote_AddVotable(string nextMode)
{
	if ( nextMode == "" || GameTypeVote_Type_FromString(nextMode) == NULL )
		return false;

	for(int j = 0; j < mapvote_count; ++j)
		if(mapvote_maps[j] == nextMode)
			return false;

	mapvote_maps[mapvote_count] = strzone(nextMode);
	mapvote_maps_suggested[mapvote_count] = false;

	mapvote_maps_screenshot_dir[mapvote_count] = 0;
	mapvote_maps_pakfile[mapvote_count] = strzone("");
	mapvote_maps_flags[mapvote_count] = GameTypeVote_AvailabilityStatus(nextMode);

	++mapvote_count;

	return true;
}

bool GameTypeVote_Start()
{
	MapVote_ClearAllVotes();
	MapVote_UnzoneStrings();

	mapvote_count = 0;
	mapvote_timeout = time + autocvar_sv_vote_gametype_timeout;
	mapvote_abstain = false;
	mapvote_detail = autocvar_sv_vote_gametype_detail;

	int n = tokenizebyseparator(autocvar_sv_vote_gametype_options, " ");
	n = min(MAPVOTE_COUNT, n);

	int really_available, which_available;
	really_available = 0;
	which_available = -1;
	for(int j = 0; j < n; ++j)
	{
		if ( GameTypeVote_AddVotable(argv(j)) )
		if ( mapvote_maps_flags[j] & GTV_AVAILABLE )
		{
			++really_available;
			which_available = j;
		}
	}

	mapvote_count_real = mapvote_count;

	gametypevote = true;

	const string current_gametype_string = (gametype_custom_enabled)
		? loaded_gametype_custom_string
		: MapInfo_Type_ToString(MapInfo_CurrentGametype());

	if ( really_available == 0 )
	{
		if ( mapvote_count > 0 )
			strunzone(mapvote_maps[0]);
		mapvote_maps[0] = strzone(current_gametype_string);
		current_gametype_index = 0;
		//GameTypeVote_Finished(0);
		MapVote_Finished(current_gametype_index);
		return false;
	}
	if ( really_available == 1 )
	{
		current_gametype_index = which_available;
		//GameTypeVote_Finished(which_available);
		MapVote_Finished(current_gametype_index);
		return false;
	}
	current_gametype_index = -1;
	if (autocvar_sv_vote_gametype_default_current) // find current gametype index
		for (int i = 0; i < mapvote_count_real; ++i)
			if (mapvote_maps[i] == current_gametype_string)
			{
				current_gametype_index = i;
				break;
			}

	mapvote_count_real = mapvote_count;

	mapvote_reduce_time = time + autocvar_sv_vote_gametype_reduce_time;
	mapvote_reduce_count = autocvar_sv_vote_gametype_reduce_count;
	if(mapvote_count_real < 3 || mapvote_reduce_time <= time)
		mapvote_reduce_time = 0;

	MapVote_Spawn();

	return true;
}
