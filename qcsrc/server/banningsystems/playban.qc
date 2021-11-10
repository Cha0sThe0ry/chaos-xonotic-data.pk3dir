//FEATURE: Command to permanently make troublesome players (teamkillers) unable to play and forces to spectate

#include "playban.qh"
#include <server/mutators/events.qh>
#include <server/client.qh>
#include <common/state.qh>
#include <server/command/common.qh>

REGISTER_MUTATOR(playban, true);

AUTOCVAR(sv_playban_list, string, "", "List of banned players from playing (forced to spectate)");

MUTATOR_HOOKFUNCTION(playban, ClientConnect)
{
	entity player = M_ARGV(0, entity);
	if(PlayerInList(player, autocvar_sv_playban_list))
		TRANSMUTE(Observer, player);
}

MUTATOR_HOOKFUNCTION(playban, PutClientInServer)
{
	entity player = M_ARGV(0, entity);
	if(PlayerInList(player, autocvar_sv_playban_list))
		TRANSMUTE(Observer, player);
}

MUTATOR_HOOKFUNCTION(playban, ForbidSpawn)
{
	entity player = M_ARGV(0, entity);
	if(PlayerInList(player, autocvar_sv_playban_list))
		return true;
}

MUTATOR_HOOKFUNCTION(playban, SV_ParseServerCommand)
{
	if(MUTATOR_RETURNVALUE) // command was already handled?
		return false;

	string cmd_name = M_ARGV(0, string);
	int cmd_argc = M_ARGV(1, int);

	if(cmd_name == "playban")
	{
		entity client = GetIndexedEntity(cmd_argc, 1);
		bool accepted = VerifyClientEntity(client, true, false);

		if (accepted > 0)
		{
			string theid = "";
			if(!PlayerInIPList(client, autocvar_sv_playban_list))
				theid = cons(theid, client.netaddress);
			if(!PlayerInIDList(client, autocvar_sv_playban_list))
				theid = cons(theid, client.crypto_idfp);
			LOG_INFO(strcat("Play-banning player ", GetCallerName(client), " (", argv(1), ")."));
			PutObserverInServer(client, true);
			cvar_set("sv_playban_list", cons(autocvar_sv_playban_list, theid));
		}
		else
		{
			LOG_INFO("play-ban failed: ", GetClientErrorString(accepted, argv(1)), ".");
		}

		return true;
	}

	if(cmd_name == "unplayban")
	{
		entity client = GetIndexedEntity(cmd_argc, 1);
		bool accepted = VerifyClientEntity(client, true, false);
		string original_arg = argv(1);

		if (accepted > 0)
		{
			string tmp_string = "";
			FOREACH_WORD(autocvar_sv_playban_list, it != client.netaddress,
			{
				if(client.crypto_idfp && it == substring(client.crypto_idfp, 0, strlen(it)))
					continue;
				tmp_string = cons(tmp_string, it);
			});

			cvar_set("sv_playban_list", tmp_string);
			LOG_INFO(strcat("Disabling forced to spectate player ", GetCallerName(client), " (", original_arg, ")."));
		}
		else
		{
			LOG_INFO("play-ban failed: ", GetClientErrorString(accepted, original_arg), ", attempting to unban by string.");

			string tmp_string = "";
			FOREACH_WORD(autocvar_sv_playban_list, it != original_arg,
			{
				tmp_string = cons(tmp_string, it);
			});

			cvar_set("sv_playban_list", tmp_string);
		}
		return true;
	}
}