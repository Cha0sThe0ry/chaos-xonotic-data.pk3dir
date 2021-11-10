//FEATURE: Command to permanently prevent certain players from voting, talking and playing. SUPER PUNISHMENT!

#include "superban.qh"
#include <server/mutators/events.qh>
#include <server/client.qh>
#include <common/state.qh>
#include <server/command/common.qh>

REGISTER_MUTATOR(superban, true);

AUTOCVAR(sv_superban_list, string, "", "List of super banned players from voting, talking and playing (forced to spectate)");

MUTATOR_HOOKFUNCTION(superban, ClientConnect)
{
	entity player = M_ARGV(0, entity);
	if(PlayerInList(player, autocvar_sv_superban_list))
    {
        CS(player).muted = true;
		TRANSMUTE(Observer, player);
    }
}

MUTATOR_HOOKFUNCTION(superban, PutClientInServer)
{
	entity player = M_ARGV(0, entity);
	if(PlayerInList(player, autocvar_sv_superban_list))
		TRANSMUTE(Observer, player);
}

MUTATOR_HOOKFUNCTION(superban, ForbidSpawn)
{
	entity player = M_ARGV(0, entity);
	if(PlayerInList(player, autocvar_sv_superban_list))
		return true;
}

MUTATOR_HOOKFUNCTION(superban, VoteCommand_Parse)
{
	entity caller = M_ARGV(0, entity);
	if(PlayerInList(caller, autocvar_sv_superban_list))
		return MUT_VOTEPARSE_UNACCEPTABLE;
}

MUTATOR_HOOKFUNCTION(superban, SV_ParseServerCommand)
{
	if(MUTATOR_RETURNVALUE) // command was already handled?
		return false;

	string cmd_name = M_ARGV(0, string);
	int cmd_argc = M_ARGV(1, int);

	if(cmd_name == "superban")
	{
		entity client = GetIndexedEntity(cmd_argc, 1);
		bool accepted = VerifyClientEntity(client, true, false);

		if (accepted > 0)
		{
			string theid = "";
			if(!PlayerInIPList(client, autocvar_sv_superban_list))
				theid = cons(theid, client.netaddress);
			if(!PlayerInIDList(client, autocvar_sv_superban_list))
				theid = cons(theid, client.crypto_idfp);
            CS(client).muted = true;
			LOG_INFO(strcat("Play-banning player ", GetCallerName(client), " (", argv(1), ")."));
			PutObserverInServer(client, true);
			cvar_set("sv_superban_list", cons(autocvar_sv_superban_list, theid));
		}
		else
		{
			LOG_INFO("super-ban failed: ", GetClientErrorString(accepted, argv(1)), ".");
		}

		return true;
	}

	if(cmd_name == "unsuperban")
	{
		entity client = GetIndexedEntity(cmd_argc, 1);
		bool accepted = VerifyClientEntity(client, true, false);
		string original_arg = argv(1);

		if (accepted > 0)
		{
			string tmp_string = "";
			FOREACH_WORD(autocvar_sv_superban_list, it != client.netaddress,
			{
				if(client.crypto_idfp && it == substring(client.crypto_idfp, 0, strlen(it)))
					continue;
				tmp_string = cons(tmp_string, it);
			});

			cvar_set("sv_superban_list", tmp_string);
			LOG_INFO(strcat("Releasing superbanned player ", GetCallerName(client), " (", original_arg, ")."));
            CS(client).muted = false;
		}
		else
		{
			LOG_INFO("super-ban failed: ", GetClientErrorString(accepted, original_arg), ", attempting to unban by string.");

			string tmp_string = "";
			FOREACH_WORD(autocvar_sv_superban_list, it != original_arg,
			{
				tmp_string = cons(tmp_string, it);
			});

			cvar_set("sv_superban_list", tmp_string);
		}
		return true;
	}
}