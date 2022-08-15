#include "stunning.qh"

#ifdef SVQC
METHOD(Stunning, m_remove, void(StatusEffects this, entity actor, int removal_type))
{
    actor.effects &= ~EF_SHOCK;
    SUPER(Stunning).m_remove(this, actor, removal_type);
}
METHOD(Stunning, m_persistent, bool(StatusEffects this, entity actor))
{
    return true;
}
METHOD(Stunning, m_tick, void(StatusEffects this, entity actor))
{
    if(STAT(FROZEN, actor))
    {
        this.m_remove(this, actor, STATUSEFFECT_REMOVE_NORMAL);
        return;
    }
    //Shock_ApplyDamage(actor);
    actor.effects |= EF_SHOCK;
    SUPER(Stunning).m_tick(this, actor);
}
#endif
