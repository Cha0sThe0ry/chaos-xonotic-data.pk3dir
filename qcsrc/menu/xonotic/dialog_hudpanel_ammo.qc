#include "dialog_hudpanel_ammo.qh"

#include "slider.qh"
#include "checkbox.qh"
#include "textlabel.qh"
#include "radiobutton.qh"

void XonoticHUDAmmoDialog_fill(entity me)
{
	entity e;
	string panelname = "ammo";

	dialog_hudpanel_main_checkbox(me, panelname);

	dialog_hudpanel_main_settings(me, panelname);

	me.TR(me);
		me.TD(me, 1, 4, e = makeXonoticCheckBox(0, "hud_panel_ammo_onlycurrent", _("Show only current ammo type")));
	me.TR(me);
		me.TDempty(me, 0.2);
		me.TD(me, 1, 1.2, e = makeXonoticTextLabel(0, _("Noncurrent alpha:")));
			setDependent(e, "hud_panel_ammo_onlycurrent", 0, 0);
		me.TD(me, 1, 2.6, e = makeXonoticSlider(0, 1, 0.1, "hud_panel_ammo_noncurrent_alpha"));
			setDependent(e, "hud_panel_ammo_onlycurrent", 0, 0);
	me.TR(me);
		me.TDempty(me, 0.2);
		me.TD(me, 1, 1.2, e = makeXonoticTextLabel(0, _("Noncurrent scale:")));
			setDependent(e, "hud_panel_ammo_onlycurrent", 0, 0);
		me.TD(me, 1, 2.6, e = makeXonoticSlider(0, 1, 0.1, "hud_panel_ammo_noncurrent_scale"));
			setDependent(e, "hud_panel_ammo_onlycurrent", 0, 0);

	me.TR(me);
		me.TD(me, 1, 1.4, e = makeXonoticTextLabel(0, _("Align icon:")));
			me.TD(me, 1, 2.6/2, e = makeXonoticRadioButton(2, "hud_panel_ammo_iconalign", "0", _("Left")));
			me.TD(me, 1, 2.6/2, e = makeXonoticRadioButton(2, "hud_panel_ammo_iconalign", "1", _("Right")));

	me.TR(me);
		me.TD(me, 1, 4, e = makeXonoticCheckBox(0, "hud_panel_ammo_progressbar", _("Enable status bar")));
}
