#include "sv_ammo_drop.qh"

float autocvar_g_ammo_drop_spread; ///< ammo spread from the point of death
float autocvar_g_ammo_drop_lifetime; ///< ammo drop's lifetime
float autocvar_g_ammo_drop_shell_count; ///< Shell ammo count
float autocvar_g_ammo_drop_bullet_count; ///< bullet ammo count
float autocvar_g_ammo_drop_rocket_count; ///< Rocket ammo count
float autocvar_g_ammo_drop_cell_count; ///< Cell ammo count

bool ammo_drop_is_spawning = false;

void AmmoDrop_SpawnAmmo(entity ammo_type, int count, vector position)
{

	if (count == 0) {
		return; // If ammo count is not specified, don't drop ammo of that type
	}
	vector spread = '0 0 0';
	spread.z = autocvar_g_ammo_drop_spread / 2;
	spread += randomvec() * autocvar_g_ammo_drop_spread;

	ammo_drop_is_spawning = true;
	entity item = spawn();
	item.itemdef = ammo_type;
	item.origin = position;
	item.velocity = spread;
	item.lifetime = autocvar_g_ammo_drop_lifetime;

	Item_Initialise(item);

	ammo_drop_is_spawning = false;
}


MUTATOR_HOOKFUNCTION(ammo_drop, BuildMutatorsString)
{
	M_ARGV(0, string) = strcat(M_ARGV(0, string), ":ammo_drop");
}

MUTATOR_HOOKFUNCTION(ammo_drop, BuildMutatorsPrettyString)
{
	M_ARGV(0, string) = strcat(M_ARGV(0, string), ", Random items");
}


MUTATOR_HOOKFUNCTION(ammo_drop, FilterItem, CBC_ORDER_LAST)
{
	if (!autocvar_g_ammo_drop)
	{
		return false;
	}

	if (ammo_drop_is_spawning == true)
	{
		return false;
	}
	entity item = M_ARGV(0, entity);
	if (ITEM_IS_LOOT(item))
	{
		return false;
	}
	return true;

}


/// \brief Hook which is called when the player dies.
MUTATOR_HOOKFUNCTION(ammo_drop, PlayerDies)
{
	//PrintToChatAll("PlayerDies");
	if (!autocvar_g_ammo_drop)
	{
		return;
	}
	entity victim = M_ARGV(2, entity);
	vector loot_position = victim.origin + '0 0 32';

	AmmoDrop_SpawnAmmo(ITEM_Shells, autocvar_g_ammo_drop_shell_count, loot_position);
	AmmoDrop_SpawnAmmo(ITEM_Bullets, autocvar_g_ammo_drop_bullet_count, loot_position);
  AmmoDrop_SpawnAmmo(ITEM_Rockets, autocvar_g_ammo_drop_rocket_count, loot_position);
	AmmoDrop_SpawnAmmo(ITEM_Cells, autocvar_g_ammo_drop_cell_count, loot_position);
}
