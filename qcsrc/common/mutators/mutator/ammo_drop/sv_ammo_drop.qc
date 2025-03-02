#include "sv_ammo_drop.qh"

float autocvar_g_ammo_drop_spread; ///< ammo spread from the point of death
float autocvar_g_ammo_drop_lifetime; ///< ammo drop's lifetime
float autocvar_g_ammo_drop_shell_ammo; ///< Shell ammo count
float autocvar_g_ammo_drop_bullet_ammo; ///< bullet ammo count
float autocvar_g_ammo_drop_rocket_ammo; ///< Rocket ammo count
float autocvar_g_ammo_drop_cell_ammo; ///< Cell ammo count

void AmmoDrop_SpawnAmmo(string ammo_type, int count, vector position)
{

	if (count == 0) {
		return; // If ammo count is not specified, don't drop ammo of that type
	}
	vector spread = '0 0 0';
	spread.z = autocvar_g_ammo_drop_spread / 2;
	spread += randomvec() * autocvar_g_ammo_drop_spread;

	entity item = spawn();
	item.classname = ammo_type;
	item.origin = position;
	item.velocity = spread;
	item.lifetime = autocvar_g_ammo_drop_lifetime;

	Item_Initialise(item);

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

	AmmoDrop_SpawnAmmo("item_shells", autocvar_g_ammo_drop_shell_ammo, loot_position);
	AmmoDrop_SpawnAmmo("item_bullets", autocvar_g_ammo_drop_bullet_ammo, loot_position);
  AmmoDrop_SpawnAmmo("item_rockets", autocvar_g_ammo_drop_rocket_ammo, loot_position);
	AmmoDrop_SpawnAmmo("item_cells", autocvar_g_ammo_drop_cell_ammo, loot_position);
}
