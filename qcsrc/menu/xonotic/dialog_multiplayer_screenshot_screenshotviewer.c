#ifdef INTERFACE
CLASS(XonoticScreenshotViewerDialog) EXTENDS(XonoticDialog)
	METHOD(XonoticScreenshotViewerDialog, fill, void(entity))
	METHOD(XonoticScreenshotViewerDialog, keyDown, float(entity, float, float, float))
	METHOD(XonoticScreenshotViewerDialog, loadScreenshot, void(entity, string))
	METHOD(XonoticScreenshotViewerDialog, close, void(entity))
	ATTRIB(XonoticScreenshotViewerDialog, title, string, "Screenshot Viewer")
	ATTRIB(XonoticScreenshotViewerDialog, name, string, "ScreenshotViewer")
	ATTRIB(XonoticScreenshotViewerDialog, intendedWidth, float, 1)
	ATTRIB(XonoticScreenshotViewerDialog, rows, float, 25)
	ATTRIB(XonoticScreenshotViewerDialog, columns, float, 4)
	ATTRIB(XonoticScreenshotViewerDialog, color, vector, SKINCOLOR_DIALOG_SCREENSHOTVIEWER)
	ATTRIB(XonoticScreenshotViewerDialog, scrList, entity, NULL)
	ATTRIB(XonoticScreenshotViewerDialog, screenshotImage, entity, NULL)
	ATTRIB(XonoticScreenshotViewerDialog, slideShowButton, entity, NULL)
	ATTRIB(XonoticScreenshotViewerDialog, currentScrPath, string, string_null)
ENDCLASS(XonoticScreenshotViewerDialog)
#endif

#ifdef IMPLEMENTATION
void XonoticScreenshotViewerDialog_loadScreenshot(entity me, string scrImage)
{
	if (me.currentScrPath == scrImage)
		return;
	if (me.currentScrPath)
		strunzone(me.currentScrPath);
	me.currentScrPath = strzone(scrImage);
	me.screenshotImage.configureXonoticScreenshotImage(me.screenshotImage, me.currentScrPath);
}
void prevScreenshot_Click(entity btn, entity me)
{
	me.scrList.goScreenshot(me.scrList, -1);
}
void nextScreenshot_Click(entity btn, entity me)
{
	me.scrList.goScreenshot(me.scrList, +1);
}
void increaseZoom_Click(entity btn, entity me)
{
	me.screenshotImage.setZoom(me.screenshotImage, -2, FALSE);
}
void decreaseZoom_Click(entity btn, entity me)
{
	me.screenshotImage.setZoom(me.screenshotImage, -1/2, FALSE);
}
void resetZoom_Click(entity btn, entity me)
{
	me.screenshotImage.setZoom(me.screenshotImage, 0, FALSE);
}
void toggleSlideShow_Click(entity btn, entity me)
{
	if (me.slideShowButton.forcePressed)
	{
		me.scrList.stopSlideShow(me.scrList);
		me.slideShowButton.forcePressed = 0;
	}
	else
	{
		me.scrList.startSlideShow(me.scrList);
		me.slideShowButton.forcePressed = 1;
	}
}
float XonoticScreenshotViewerDialog_keyDown(entity me, float key, float ascii, float shift)
{
	switch(key)
	{
		case K_KP_LEFTARROW:
		case K_LEFTARROW:
			me.scrList.goScreenshot(me.scrList, -1);
			return 1;
		case K_KP_RIGHTARROW:
		case K_RIGHTARROW:
			me.scrList.goScreenshot(me.scrList, +1);
			return 1;
		case K_KP_ENTER:
		case K_ENTER:
		case K_SPACE:
			// we cannot use SPACE/ENTER directly, as in a dialog they are needed
			// to press buttons while browsing with only the keyboard
			if (shift & S_CTRL)
			{
				toggleSlideShow_Click(world, me);
				return 1;
			}
			return SUPER(XonoticScreenshotViewerDialog).keyDown(me, key, ascii, shift);
		default:
			if (key == K_MWHEELUP || ascii == '+')
			{
				me.screenshotImage.setZoom(me.screenshotImage, -2, (key == K_MWHEELUP));
				return 1;
			}
			else if (key == K_MWHEELDOWN || ascii == '-')
			{
				me.screenshotImage.setZoom(me.screenshotImage, -1/2, (key == K_MWHEELDOWN));
				return 1;
			}
			if (me.scrList.keyDown(me.scrList, key, ascii, shift))
			{
				// keyDown has already changed the selected item
				me.scrList.goScreenshot(me.scrList, 0);
				return 1;
			}
			return SUPER(XonoticScreenshotViewerDialog).keyDown(me, key, ascii, shift);
	}
}
void XonoticScreenshotViewerDialog_close(entity me)
{
	me.scrList.stopSlideShow(me.scrList);
	me.slideShowButton.forcePressed = 0;
	SUPER(XonoticScreenshotViewerDialog).close(me);
}
void XonoticScreenshotViewerDialog_fill(entity me)
{
	entity e;
	me.TR(me);
		me.TD(me, me.rows - 1, me.columns, e = makeXonoticScreenshotImage());
			me.screenshotImage = e;
	me.gotoRC(me, me.rows - 1, 0);
		me.TDempty(me, 1/20 * me.columns);
		me.TD(me, 1, 1/20 * me.columns, e = makeXonoticButton("-", '0 0 0'));
			e.onClick = decreaseZoom_Click;
			e.onClickEntity = me;
		me.TD(me, 1, 1/20 * me.columns, e = makeXonoticButton("+", '0 0 0'));
			e.onClick = increaseZoom_Click;
			e.onClickEntity = me;
		me.TD(me, 1, 2/20 * me.columns, e = makeXonoticButton("reset", '0 0 0'));
			e.onClick = resetZoom_Click;
			e.onClickEntity = me;

		me.TDempty(me, 2/20 * me.columns);
		me.TD(me, 1, 3/20 * me.columns, e = makeXonoticButton("Previous", '0 0 0'));
			e.onClick = prevScreenshot_Click;
			e.onClickEntity = me;
		me.TD(me, 1, 3/20 * me.columns, e = makeXonoticButton("Next", '0 0 0'));
			e.onClick = nextScreenshot_Click;
			e.onClickEntity = me;

		me.TDempty(me, 2/20 * me.columns);
		me.TD(me, 1, 4/20 * me.columns, e = makeXonoticButton("Slide show", '0 0 0'));
			e.onClick = toggleSlideShow_Click;
			e.onClickEntity = me;
			me.slideShowButton = e;
}
#endif
