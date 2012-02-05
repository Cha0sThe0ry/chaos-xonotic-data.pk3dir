#ifdef INTERFACE
CLASS(Image) EXTENDS(Item)
	METHOD(Image, configureImage, void(entity, string))
	METHOD(Image, draw, void(entity))
	METHOD(Image, toString, string(entity))
	METHOD(Image, resizeNotify, void(entity, vector, vector, vector, vector))
	METHOD(Image, updateAspect, void(entity))
	METHOD(Image, initZoom, void(entity))
	METHOD(Image, setZoom, void(entity, float, float))
	METHOD(Image, drag_setStartPos, float(entity, vector))
	METHOD(Image, drag, float(entity, vector))
	ATTRIB(Image, src, string, string_null)
	ATTRIB(Image, color, vector, '1 1 1')
	ATTRIB(Image, forcedAspect, float, 0) // special values: -1 keep image aspect ratio, -2 keep image size but bound to the containing box, -3 always keep image size
	ATTRIB(Image, initialForcedZoom, float, 0) // used by forcedAspect -2 when the image is larger than the containing box
	ATTRIB(Image, zoomFactor, float, 1)
	ATTRIB(Image, zoomOffset, vector, '0.5 0.5 0')
	ATTRIB(Image, zoomTime, float, 0)
	ATTRIB(Image, zoomLimitedByTheBox, float, 0) // forbids zoom if image would be larger than the containing box
	ATTRIB(Image, zoomMax, float, 0)
	ATTRIB(Image, start_zoomOffset, vector, '0 0 0')
	ATTRIB(Image, start_coords, vector, '0 0 0')
	ATTRIB(Image, imgOrigin, vector, '0 0 0')
	ATTRIB(Image, imgSize, vector, '0 0 0')
ENDCLASS(Image)
#endif

#ifdef IMPLEMENTATION
string Image_toString(entity me)
{
	return me.src;
}
void Image_configureImage(entity me, string path)
{
	me.src = path;
}
void Image_initZoom(entity me)
{
	me.zoomOffset = '0.5 0.5 0';
	me.zoomFactor = 1;
	if (me.forcedAspect == -2)
		me.initialForcedZoom = -1; // calculate initialForcedZoom at the first updateAspect call
	if (me.zoomLimitedByTheBox)
		me.zoomMax = -1; // calculate zoomMax at the first updateAspect call
}

void Image_draw(entity me)
{
	if(me.imgSize_x > 1 || me.imgSize_y > 1)
		draw_SetClip();
	draw_Picture(me.imgOrigin, me.src, me.imgSize, me.color, 1);
	if(me.imgSize_x > 1 || me.imgSize_y > 1)
		draw_ClearClip();
	SUPER(Image).draw(me);
}
void Image_updateAspect(entity me)
{
	float asp;
	if(me.size_x <= 0 || me.size_y <= 0)
		return;
	if(me.forcedAspect == 0)
	{
		me.imgOrigin = '0 0 0';
		me.imgSize = '1 1 0';
	}
	else
	{
		if(me.forcedAspect < 0)
		{
			vector sz;
			sz = draw_PictureSize(me.src);
			asp = sz_x / sz_y;
		}
		else
			asp = me.forcedAspect;

		if(me.forcedAspect <= -2)
		{
			me.imgSize_x = sz_x / me.size_x;
			me.imgSize_y = sz_y / me.size_y;
			if(me.initialForcedZoom < 0 && (me.imgSize_x > 1 || me.imgSize_y > 1))
			{
				// image larger than the containing box, zoom it out to fit into the box
				if(me.size_x > asp * me.size_y)
					me.initialForcedZoom = (me.size_y * asp / me.size_x) / me.imgSize_x;
				else
					me.initialForcedZoom = (me.size_x / (asp * me.size_y)) / me.imgSize_y;
				me.zoomFactor = me.initialForcedZoom;
			}
		}
		else
		{
			if(me.size_x > asp * me.size_y)
			{
				// x too large, so center x-wise
				me.imgSize = eY + eX * (me.size_y * asp / me.size_x);
			}
			else
			{
				// y too large, so center y-wise
				me.imgSize = eX + eY * (me.size_x / (asp * me.size_y));
			}
		}
	}

	if (me.zoomMax < 0)
	{
		if(me.initialForcedZoom > 0)
			me.zoomMax = me.initialForcedZoom;
		else
		{
			if(me.size_x > asp * me.size_y)
				me.zoomMax = (me.size_y * asp / me.size_x) / me.imgSize_x;
			else
				me.zoomMax = (me.size_x / (asp * me.size_y)) / me.imgSize_y;
		}
	}

	if (me.zoomMax > 0 && me.zoomFactor > me.zoomMax)
		me.zoomFactor = me.zoomMax;
	if (me.zoomFactor)
		me.imgSize = me.imgSize * me.zoomFactor;

	if(me.imgSize_x > 1 || me.imgSize_y > 1)
	{
		me.zoomOffset_x = bound(0, me.zoomOffset_x, 1);
		me.zoomOffset_y = bound(0, me.zoomOffset_y, 1);
	}
	else
		me.zoomOffset = '0.5 0.5 0';

	me.imgOrigin_x = 0.5 - me.zoomOffset_x * me.imgSize_x;
	me.imgOrigin_y = 0.5 - me.zoomOffset_y * me.imgSize_y;
}
float Image_drag_setStartPos(entity me, vector coords)
{
	//if(me.imgSize_x > 1 || me.imgSize_y > 1) // check disabled: mousewheel zoom may start from a non-zoomed-in image
	{
		me.start_zoomOffset = me.zoomOffset;
		me.start_coords = coords;
	}
	return 1;
}
float Image_drag(entity me, vector coords)
{
	if(me.imgSize_x > 1 || me.imgSize_y > 1)
	{
		me.zoomOffset_x = me.start_zoomOffset_x + (me.start_coords_x - coords_x) / me.imgSize_x;
		me.zoomOffset_y = me.start_zoomOffset_y + (me.start_coords_y - coords_y) / me.imgSize_y;
		me.updateAspect(me);
	}
	return 1;
}
void Image_setZoom(entity me, float z, float atMousePosition)
{
	float prev_zoomFactor;
	prev_zoomFactor = me.zoomFactor;
	if (z < 0) // multiply by the current zoomFactor
	{
		me.zoomFactor *= -z;
		float one_in_the_middle, initialZoom_in_the_middle;
		one_in_the_middle = ((prev_zoomFactor - 1) * (me.zoomFactor - 1) < 0);
		initialZoom_in_the_middle = (me.initialForcedZoom > 0 && (prev_zoomFactor - me.initialForcedZoom) * (me.zoomFactor - me.initialForcedZoom) < 0);
		if (one_in_the_middle && initialZoom_in_the_middle)
		{
			// snap to real dimensions or to box
			if (prev_zoomFactor < me.zoomFactor)
				me.zoomFactor = min(1, me.initialForcedZoom);
			else
				me.zoomFactor = max(1, me.initialForcedZoom);
		}
		else if (one_in_the_middle)
			me.zoomFactor = 1; // snap to real dimensions
		else if (initialZoom_in_the_middle)
			me.zoomFactor = me.initialForcedZoom; // snap to box
	}
	else if (z == 0) // reset (no zoom)
	{
		if (me.initialForcedZoom > 0)
			me.zoomFactor = me.initialForcedZoom;
		else
			me.zoomFactor = 1;
	}
	else // directly set
		me.zoomFactor = z;
	me.zoomFactor = bound(1/16, me.zoomFactor, 16);
	if (me.zoomMax > 0 && me.zoomFactor > me.zoomMax)
		me.zoomFactor = me.zoomMax;
	if (prev_zoomFactor != me.zoomFactor)
	{
		me.zoomTime = time;
		if (atMousePosition)
		{
			me.zoomOffset_x = me.start_zoomOffset_x + (me.start_coords_x - 0.5) / me.imgSize_x;
			me.zoomOffset_y = me.start_zoomOffset_y + (me.start_coords_y - 0.5) / me.imgSize_y;
			// updateAspect will reset zoomOffset to '0.5 0.5 0' if
			// with this zoomFactor the image will not be zoomed in
			// (updateAspect will check the new values of imgSize).
		}
	}
	me.updateAspect(me);
}
void Image_resizeNotify(entity me, vector relOrigin, vector relSize, vector absOrigin, vector absSize)
{
	SUPER(Image).resizeNotify(me, relOrigin, relSize, absOrigin, absSize);
	me.updateAspect(me);
}
#endif
