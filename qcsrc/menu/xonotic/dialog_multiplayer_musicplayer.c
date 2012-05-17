#ifdef INTERFACE
CLASS(XonoticMusicPlayerTab) EXTENDS(XonoticTab)
	METHOD(XonoticMusicPlayerTab, fill, void(entity))
	ATTRIB(XonoticMusicPlayerTab, title, string, _("Music"))
	ATTRIB(XonoticMusicPlayerTab, intendedWidth, float, 0.9)
	ATTRIB(XonoticMusicPlayerTab, rows, float, 22)
	ATTRIB(XonoticMusicPlayerTab, columns, float, 6.2)
	ATTRIB(XonoticMusicPlayerTab, name, string, "MusicPlayer")
ENDCLASS(XonoticMusicPlayerTab)
entity makeXonoticMusicPlayerTab();
#endif

#ifdef IMPLEMENTATION
entity makeXonoticMusicPlayerTab()
{
	entity me;
	me = spawnXonoticMusicPlayerTab();
	me.configureDialog(me);
	return me;
}
void XonoticMusicPlayerTab_fill(entity me)
{
	entity e;
	entity btn;
	entity soundList, playList;
	float columns_nospacing = (me.columns - 0.2);

	me.TR(me);
		me.TD(me, 1, 0.5, e = makeXonoticTextLabel(0, _("Filter:")));
		me.TD(me, 1, 0.5, btn = makeXonoticButton(_("Clear"), '0 0 0'));
			btn.onClick = InputBox_Clear_Click;
		me.TD(me, 1, 2, e = makeXonoticInputBox(0, string_null));
			soundList = makeXonoticSoundList();
			e.onChange = SoundList_Filter_Change;
			e.onChangeEntity = soundList;
			btn.onClickEntity = e;
			soundList.controlledTextbox = e;
			playList = makeXonoticPlayList();
			soundList.playlist = playList;

	me.TR(me);
		me.TD(me, me.rows - 4, columns_nospacing / 2, soundList);

	me.gotoRC(me, me.rows - 3, 0);
		me.TD(me, 1, columns_nospacing / 2, e = makeXonoticButton(_("Set as menu track"), '0 0 0'));
			e.onClick = SoundList_Menu_Track_Change;
			e.onClickEntity = soundList;
	me.TR(me);
		me.TD(me, 1, columns_nospacing / 2, e = makeXonoticButton(_("Reset default menu track"), '0 0 0'));
			e.onClick = SoundList_Menu_Track_Reset;
			e.onClickEntity = soundList;
	me.TR(me);
	me.TR(me);
	me.gotoRC(me, 0, columns_nospacing / 2 + 0.2); me.setFirstColumn(me, me.currentColumn);
		me.TD(me, 1, columns_nospacing / 4, e = makeXonoticTextLabel(0, _("Playlist:")));
		me.TD(me, 1, columns_nospacing / 4, e = makeXonoticCheckBox(0, "music_playlist_random0", _("Random order")));
	me.TR(me);
		me.TD(me, me.rows - 3, columns_nospacing / 2, playList);

	me.gotoRC(me, me.rows - 2, columns_nospacing / 2 + 0.2);
		me.TD(me, 1, columns_nospacing / 10, e = makeXonoticButton(ZCTX(_("MP^Stop")), '0 0 0'));
			e.onClick = StopSound_Click;
			e.onClickEntity = playList;
		me.TD(me, 1, columns_nospacing / 10, e = makeXonoticButton(ZCTX(_("MP^Play")), '0 0 0'));
			e.onClick = StartSound_Click;
			e.onClickEntity = playList;
		me.TD(me, 1, columns_nospacing / 10, e = makeXonoticButton(ZCTX(_("MP^Pause/Play")), '0 0 0'));
			e.onClick = PauseSound_Click;
			e.onClickEntity = playList;
		me.TD(me, 1, columns_nospacing / 10, e = makeXonoticButton(ZCTX(_("MP^Prev")), '0 0 0'));
			e.onClick = PrevSound_Click;
			e.onClickEntity = playList;
		me.TD(me, 1, columns_nospacing / 10, e = makeXonoticButton(ZCTX(_("MP^Next")), '0 0 0'));
			e.onClick = NextSound_Click;
			e.onClickEntity = playList;
}
#endif
