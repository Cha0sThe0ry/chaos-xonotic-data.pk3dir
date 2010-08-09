#ifdef INTERFACE
CLASS(XonoticScreenshotList) EXTENDS(XonoticListBox)
	METHOD(XonoticScreenshotList, configureXonoticScreenshotList, void(entity))
	ATTRIB(XonoticScreenshotList, rowsPerItem, float, 1)
	METHOD(XonoticScreenshotList, resizeNotify, void(entity, vector, vector, vector, vector))
	METHOD(XonoticScreenshotList, drawListBoxItem, void(entity, float, vector, float))
	METHOD(XonoticScreenshotList, getScreenshots, void(entity))
	METHOD(XonoticScreenshotList, previewScreenshot, void(entity))
	METHOD(XonoticScreenshotList, startScreenshot, void(entity))
	METHOD(XonoticScreenshotList, screenshotName, string(entity, float))
	METHOD(XonoticScreenshotList, clickListBoxItem, void(entity, float, vector))
	METHOD(XonoticScreenshotList, keyDown, float(entity, float, float, float))
	METHOD(XonoticScreenshotList, destroy, void(entity))
	METHOD(XonoticScreenshotList, showNotify, void(entity))
	ATTRIB(XonoticScreenshotList, listScreenshot, float, -1)
	ATTRIB(XonoticScreenshotList, realFontSize, vector, '0 0 0')
	ATTRIB(XonoticScreenshotList, columnNameOrigin, float, 0)
	ATTRIB(XonoticScreenshotList, columnNameSize, float, 0)
	ATTRIB(XonoticScreenshotList, realUpperMargin, float, 0)
	ATTRIB(XonoticScreenshotList, origin, vector, '0 0 0')
	ATTRIB(XonoticScreenshotList, itemAbsSize, vector, '0 0 0')
	ATTRIB(XonoticScreenshotList, lastClickedScreenshot, float, -1)
	ATTRIB(XonoticScreenshotList, lastClickedTime, float, 0)
	ATTRIB(XonoticScreenshotList, filterString, string, string_null)

	ATTRIB(XonoticScreenshotList, screenshotBrowserDialog, entity, NULL)
	ATTRIB(XonoticScreenshotList, screenshotPreview, entity, NULL)
	ATTRIB(XonoticScreenshotList, screenshotViewerDialog, entity, NULL)
	METHOD(XonoticScreenshotList, goScreenshot, void(entity, float))
ENDCLASS(XonoticScreenshotList)

entity makeXonoticScreenshotList();
void StartScreenshot_Click(entity btn, entity me);
void ScreenshotList_Filter_Change(entity box, entity me);
#endif

#ifdef IMPLEMENTATION

entity makeXonoticScreenshotList()
{
	entity me;
	me = spawnXonoticScreenshotList();
	me.configureXonoticScreenshotList(me);
	return me;
}

void XonoticScreenshotList_configureXonoticScreenshotList(entity me)
{
	me.configureXonoticListBox(me);
	me.getScreenshots(me);
}

string XonoticScreenshotList_screenshotName(entity me, float i )
{
	string s;
	s = bufstr_get(me.listScreenshot, i);
	s = substring(s, 12, strlen(s) - 12 - 4);  // screenshots/, .<ext>
	return s;
}

// if subdir is TRUE look in subdirectories too (1 level)
void getScreenshots_for_ext(entity me, string ext, float subdir)
{
	string s;
	if (subdir)
		s="screenshots/*/";
	else
		s="screenshots/";
	if(me.filterString)
		s=strcat(s, me.filterString, ext);
	else
		s=strcat(s, "*", ext);

	float list, i, n;
	list = search_begin(s, FALSE, TRUE);
	if(list >= 0)
	{
		n = search_getsize(list);
		for(i = 0; i < n; ++i)
			bufstr_add(me.listScreenshot, search_getfilename(list, i), TRUE);
		search_end(list);
	}

	if (subdir)
		getScreenshots_for_ext(me, ext, FALSE);
}

void XonoticScreenshotList_getScreenshots(entity me)
{
	if (me.listScreenshot >= 0)
		buf_del(me.listScreenshot);
	me.listScreenshot = buf_create();
	if (me.listScreenshot < 0)
	{
		me.nItems = 0;
		return;
	}
	getScreenshots_for_ext(me, ".jpg", TRUE);
	getScreenshots_for_ext(me, ".tga", TRUE);
	getScreenshots_for_ext(me, ".png", TRUE);
	me.nItems = buf_getsize(me.listScreenshot);
	buf_sort(me.listScreenshot, 128, FALSE);
}

void XonoticScreenshotList_destroy(entity me)
{
	buf_del(me.listScreenshot);
}

void XonoticScreenshotList_resizeNotify(entity me, vector relOrigin, vector relSize, vector absOrigin, vector absSize)
{
	me.itemAbsSize = '0 0 0';
	SUPER(XonoticScreenshotList).resizeNotify(me, relOrigin, relSize, absOrigin, absSize);

	me.realFontSize_y = me.fontSize / (me.itemAbsSize_y = (absSize_y * me.itemHeight));
	me.realFontSize_x = me.fontSize / (me.itemAbsSize_x = (absSize_x * (1 - me.controlWidth)));
	me.realUpperMargin = 0.5 * (1 - me.realFontSize_y);

	me.columnNameOrigin = me.realFontSize_x;
	me.columnNameSize = 1 - 2 * me.realFontSize_x;
}

void XonoticScreenshotList_drawListBoxItem(entity me, float i, vector absSize, float isSelected)
{
	string s;
	if(isSelected)
	{
		draw_Fill('0 0 0', '1 1 0', SKINCOLOR_LISTBOX_SELECTED, SKINALPHA_LISTBOX_SELECTED);
		me.previewScreenshot(me);
	}

	s = me.screenshotName(me,i);
	s = draw_TextShortenToWidth(s, me.columnNameSize, 0, me.realFontSize);
	draw_Text(me.realUpperMargin * eY + (me.columnNameOrigin + 0.00 * (me.columnNameSize - draw_TextWidth(s, 0, me.realFontSize))) * eX, s, me.realFontSize, '1 1 1', SKINALPHA_TEXT, 0);
}

void XonoticScreenshotList_showNotify(entity me)
{
	me.getScreenshots(me);
}

void ScreenshotList_Filter_Change(entity box, entity me)
{
	if(me.filterString)
		strunzone(me.filterString);

	if(box.text != "")
	{
		if (strstrofs(box.text, "*", 0) >= 0 || strstrofs(box.text, "?", 0) >= 0)
			me.filterString = strzone(box.text);
		else
			me.filterString = strzone(strcat("*", box.text, "*"));
	}
	else
		me.filterString = string_null;

	me.getScreenshots(me);
	me.setSelected(me, 0); //alway select the first element after a new search
}

void XonoticScreenshotList_goScreenshot(entity me, float d)
{
	if(!me.screenshotViewerDialog)
		return;
	me.setSelected(me, me.selectedItem + d);
	me.screenshotViewerDialog.loadScreenshot(me.screenshotViewerDialog, strcat("/screenshots/", me.screenshotName(me,me.selectedItem)));
}

void XonoticScreenshotList_startScreenshot(entity me)
{
	me.screenshotViewerDialog.loadScreenshot(me.screenshotViewerDialog, strcat("/screenshots/", me.screenshotName(me,me.selectedItem)));
	// pop up screenshot
	DialogOpenButton_Click_withCoords(NULL, me.screenshotViewerDialog, me.origin + eX * (me.columnNameOrigin * me.size_x) + eY * ((me.itemHeight * me.selectedItem - me.scrollPos) * me.size_y), eY * me.itemAbsSize_y + eX * (me.itemAbsSize_x * me.columnNameSize));
}

void XonoticScreenshotList_previewScreenshot(entity me)
{
	if(!me.screenshotBrowserDialog)
		return;
	me.screenshotBrowserDialog.loadPreviewScreenshot(me.screenshotBrowserDialog, strcat("/screenshots/", me.screenshotName(me,me.selectedItem)));
}

void StartScreenshot_Click(entity btn, entity me)
{
	me.startScreenshot(me);
}

void XonoticScreenshotList_clickListBoxItem(entity me, float i, vector where)
{
	if(i == me.lastClickedScreenshot)
		if(time < me.lastClickedTime + 0.3)
		{
			// DOUBLE CLICK!
			// pop up screenshot
			me.setSelected(me, i);
			me.startScreenshot(me);
		}
	me.lastClickedScreenshot = i;
	me.lastClickedTime = time;
}

float XonoticScreenshotList_keyDown(entity me, float scan, float ascii, float shift)
{
	if(scan == K_ENTER || scan == K_KP_ENTER) {
		me.startScreenshot(me);
		return 1;
	}
	else
		return SUPER(XonoticScreenshotList).keyDown(me, scan, ascii, shift);
}
#endif
