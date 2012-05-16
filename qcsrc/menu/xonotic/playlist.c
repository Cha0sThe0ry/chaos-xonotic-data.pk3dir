#ifdef INTERFACE
CLASS(XonoticPlayList) EXTENDS(XonoticListBox)
	METHOD(XonoticPlayList, configureXonoticPlayList, void(entity))
	ATTRIB(XonoticPlayList, rowsPerItem, float, 1)
	METHOD(XonoticPlayList, resizeNotify, void(entity, vector, vector, vector, vector))
	METHOD(XonoticPlayList, draw, void(entity))
	METHOD(XonoticPlayList, drawListBoxItem, void(entity, float, vector, float))
	METHOD(XonoticPlayList, stopSound, void(entity))
	METHOD(XonoticPlayList, startSound, void(entity, float))
	METHOD(XonoticPlayList, pauseSound, void(entity))
	METHOD(XonoticPlayList, clickListBoxItem, void(entity, float, vector))
	METHOD(XonoticPlayList, keyDown, float(entity, float, float, float))

	METHOD(XonoticPlayList, addToPlayList, void(entity, string))
	METHOD(XonoticPlayList, removeFromPlayList, void(entity, string))
	ATTRIB(XonoticPlayList, playingTrack, string, string_null)

	ATTRIB(XonoticPlayList, realFontSize, vector, '0 0 0')
	ATTRIB(XonoticPlayList, columnNameOrigin, float, 0)
	ATTRIB(XonoticPlayList, columnNameSize, float, 0)
	ATTRIB(XonoticPlayList, realUpperMargin, float, 0)
	ATTRIB(XonoticPlayList, origin, vector, '0 0 0')
	ATTRIB(XonoticPlayList, itemAbsSize, vector, '0 0 0')

	ATTRIB(XonoticPlayList, lastClickedSound, float, -1)
	ATTRIB(XonoticPlayList, lastClickedTime, float, 0)
ENDCLASS(XonoticPlayList)

entity makeXonoticPlayList();
void StopSound_Click(entity btn, entity me);
void StartSound_Click(entity btn, entity me);
void PauseSound_Click(entity btn, entity me);
void PrevSound_Click(entity btn, entity me);
void NextSound_Click(entity btn, entity me);
#endif

#ifdef IMPLEMENTATION

entity makeXonoticPlayList()
{
	entity me;
	me = spawnXonoticPlayList();
	me.configureXonoticPlayList(me);
	return me;
}

void XonoticPlayList_configureXonoticPlayList(entity me)
{
	me.nItems = tokenize_console(cvar_string("music_playlist_list0"));
	me.configureXonoticListBox(me);
}

void XonoticPlayList_resizeNotify(entity me, vector relOrigin, vector relSize, vector absOrigin, vector absSize)
{
	me.itemAbsSize = '0 0 0';
	SUPER(XonoticPlayList).resizeNotify(me, relOrigin, relSize, absOrigin, absSize);

	me.realFontSize_y = me.fontSize / (me.itemAbsSize_y = (absSize_y * me.itemHeight));
	me.realFontSize_x = me.fontSize / (me.itemAbsSize_x = (absSize_x * (1 - me.controlWidth)));
	me.realUpperMargin = 0.5 * (1 - me.realFontSize_y);

	me.columnNameOrigin = me.realFontSize_x;
	me.columnNameSize = 1 - 2 * me.realFontSize_x;
}

void XonoticPlayList_addToPlayList(entity me, string track)
{
	// TODO: append instead of add
	float old_nItems = me.nItems;
	localcmd(strcat("\nmenu_cmd addtolist music_playlist_list0 ", track, "\n"));
	me.nItems = tokenize_console(cvar_string("music_playlist_list0")); // FIXME: do this one frame later
	if(me.nItems != old_nItems)
		cvar_set("music_playlist_current0", ftos(cvar("music_playlist_current0") + 1));
}

void XonoticPlayList_removeFromPlayList(entity me, string track)
{
	float old_nItems = me.nItems;
	localcmd(strcat("\nmenu_cmd removefromlist music_playlist_list0 ", track, "\n"));
	me.nItems = tokenize_console(cvar_string("music_playlist_list0")); // FIXME: do this one frame later
	if(me.nItems != old_nItems)
		cvar_set("music_playlist_current0", ftos(cvar("music_playlist_current0") - 1));
}

void XonoticPlayList_draw(entity me)
{
	me.nItems = tokenize_console(cvar_string("music_playlist_list0"));
	SUPER(XonoticPlayList).draw(me);
}

void XonoticPlayList_drawListBoxItem(entity me, float i, vector absSize, float isSelected)
{
	string s;
	if(isSelected)
		draw_Fill('0 0 0', '1 1 0', SKINCOLOR_LISTBOX_SELECTED, SKINALPHA_LISTBOX_SELECTED);

	if(argv(i) == me.playingTrack)
	{
		float f = cvar("music_playlist_sampleposition0");
		if(f == 0 || (((time * 2) & 1) && f > 0))
			draw_Text(me.realUpperMargin * eY, chr(0xE000 + 141), me.realFontSize, '1 1 1', SKINALPHA_TEXT, 0);
	}

	s = argv(i);
	s = strcat(ftos(i+1), ") ", s);
	s = draw_TextShortenToWidth(s, me.columnNameSize, 0, me.realFontSize);
	draw_Text(me.realUpperMargin * eY + me.columnNameOrigin * eX, s, me.realFontSize, '1 1 1', SKINALPHA_TEXT, 0);
}

void XonoticPlayList_stopSound(entity me)
{
	// STOP: list 0 is disabled by setting the index to -1
	// we set sampleposition0 to -1 to indicate that music is stopped
	if(cvar("music_playlist_index") != -1) // == 0 doesn't work when paused
	{
		cvar_set("music_playlist_index", "-1");
		localcmd("\nwait; music_playlist_sampleposition0 -1\n");
		localcmd("\ndefer 3 \"cd play $menu_cdtrack\"\n");
	}
}

void StopSound_Click(entity btn, entity me)
{
	me.stopSound(me);
}

void XonoticPlayList_startSound(entity me, float offset)
{
	float f;
	me.nItems = tokenize_console(cvar_string("music_playlist_list0"));
	if(offset)
	{
		f = bound(0, cvar("music_playlist_current0") + offset, me.nItems - 1);
		if(f == cvar("music_playlist_current0"))
			return;
	}
	else
		f = me.selectedItem;
	if(me.playingTrack)
		strunzone(me.playingTrack);
	me.playingTrack = strzone(argv(f));
	// START: list 0 is disabled by setting the index to 999
	// we set current0 to the selected track and sampleposition0 to 0 to forget value saved by the engine
	// then we switch back to list 0
	cvar_set("music_playlist_index", "999");
	cvar_set("music_playlist_current0", ftos(f));
	localcmd("\nwait; music_playlist_sampleposition0 0; wait; music_playlist_index 0\n");
}

void StartSound_Click(entity btn, entity me)
{
	me.startSound(me, 0);
}

void PrevSound_Click(entity btn, entity me)
{
	me.startSound(me, -1);
}

void NextSound_Click(entity btn, entity me)
{
	me.startSound(me, +1);
}

void XonoticPlayList_pauseSound(entity me)
{
	// PAUSE: list 0 is disabled by setting the index to 999
	// (we know the track is paused because the engine sets sampleposition0 to remember current position)
	// RESUME: list 0 is enabled by setting the index to 0
	// (we reset sampleposition0 to 0 to mark the track as in playing back state)
	if(cvar("music_playlist_index") == 0)
		localcmd("\nmusic_playlist_index 999\n");
	else
		localcmd("\nmusic_playlist_index 0; wait; music_playlist_sampleposition0 0\n");
}

void PauseSound_Click(entity btn, entity me)
{
	me.pauseSound(me);
}

void XonoticPlayList_clickListBoxItem(entity me, float i, vector where)
{
	if(i == me.lastClickedSound)
		if(time < me.lastClickedTime + 0.3)
		{
			// DOUBLE CLICK!
			me.setSelected(me, i);
			me.startSound(me, 0);
		}
	me.lastClickedSound = i;
	me.lastClickedTime = time;
}

float XonoticPlayList_keyDown(entity me, float scan, float ascii, float shift)
{
	if(scan == K_ENTER || scan == K_KP_ENTER) {
		me.startSound(me, 0);
		return 1;
	}
	else if(scan == K_SPACE) {
		me.pauseSound(me);
		return 1;
	}
	else if(scan == K_DEL || scan == K_KP_DEL || scan == K_BACKSPACE || scan == K_MOUSE3) {
		me.nItems = tokenize_console(cvar_string("music_playlist_list0"));
		me.removeFromPlayList(me, argv(me.selectedItem));
		return 1;
	}
	else
		return SUPER(XonoticPlayList).keyDown(me, scan, ascii, shift);
}
#endif

