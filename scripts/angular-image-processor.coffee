angular.module('tbImageProcessor').service('imageProcessor', ($q) ->
  {
    startTime: 0
    lastTime: 0

    logTime: (methName) ->
      @lastTime = Date.now()
#      logger.debug(@lastTime + ": " + methName + " (" + (@lastTime - @startTime) + ")")

    ###
    Transform canvas coordination according to specified frame size and orientation
    Orientation value is from EXIF tag
    ###
    transformCoordinate: (canvas, width, height, orientation) ->
      switch orientation
        when 5, 6, 7, 8
          canvas.width = height
          canvas.height = width
        else
          canvas.width = width
          canvas.height = height

      ctx = canvas.getContext("2d")
      switch orientation
        when 2

        # horizontal flip
          ctx.translate width, 0
          ctx.scale -1, 1
        when 3

        # 180 rotate left
          ctx.translate width, height
          ctx.rotate Math.PI
        when 4

        # vertical flip
          ctx.translate 0, height
          ctx.scale 1, -1
        when 5

        # vertical flip + 90 rotate right
          ctx.rotate 0.5 * Math.PI
          ctx.scale 1, -1
        when 6

        # 90 rotate right
          ctx.rotate 0.5 * Math.PI
          ctx.translate 0, -height
        when 7

        # horizontal flip + 90 rotate right
          ctx.rotate 0.5 * Math.PI
          ctx.translate width, -height
          ctx.scale -1, 1
        when 8

        # 90 rotate left
          ctx.rotate -0.5 * Math.PI
          ctx.translate -width, 0
        else
          #do nothing

      #end transformCoordinate

    ###
    Detecting vertical squash in loaded image.
    Fixes a bug which squash image vertically while drawing into canvas for some images.
    This is a bug in iOS6 devices. This function from https://github.com/stomita/ios-imagefile-megapixel
    ###

    detectVerticalSquash: (img) ->
      iw = img.naturalWidth
      ih = img.naturalHeight
      canvas = document.createElement("canvas")
      canvas.width = 1
      canvas.height = ih
      ctx = canvas.getContext("2d")
      ctx.drawImage(img, 0, 0)
      data = ctx.getImageData(0, 0, 1, ih).data

      # search image edge pixel position in case it is squashed vertically.
      sy = 0
      ey = ih
      py = ih
      while py > sy
        alpha = data[(py - 1) * 4 + 3]
        if alpha is 0
          ey = py
        else
          sy = py
        py = (ey + sy) >> 1
      ratio = (py / ih)
      (if (ratio is 0) then 1 else ratio)

    ###
    A replacement for context.drawImage
    (args are for source and destination).
    ###
    drawImageIOSFix: (ctx, img, sx, sy, sw, sh, dx, dy, dw, dh) ->
      @logTime "detectVerticalSquash"
      vertSquashRatio = @detectVerticalSquash(img)
      @logTime "drawImage"

      # Works only if whole image is displayed:
      # ctx.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh / vertSquashRatio);
      # The following works correct also when only a part of the image is displayed:
      ctx.drawImage(img, sx * vertSquashRatio, sy * vertSquashRatio, sw * vertSquashRatio, sh * vertSquashRatio, dx, dy, dw, dh)
      return

    getResizeArea: ->
      resizeAreaId = "fileupload-resize-area"
      resizeArea = document.getElementById(resizeAreaId)
      unless resizeArea
        resizeArea = document.createElement("canvas")
        resizeArea.id = resizeAreaId
        resizeArea.style.visibility = "hidden"
        document.body.appendChild(resizeArea)
      resizeArea

    resizeImage: (origImage, options) ->
      deferred = $q.defer()
      maxHeight = options.resizeMaxHeight or 300
      maxWidth = options.resizeMaxWidth or 250
      quality = options.resizeQuality or 0.7
      type = 'image/jpeg' #options.resizeType or
      canvas = @getResizeArea()
      canvas.width = maxWidth
      canvas.height = maxHeight
      origWidth = origImage.width
      origHeight = origImage.height
      sourceWidth = undefined
      sourceHeight = undefined
      sourceX = undefined
      sourceY = undefined

      if origWidth < origHeight
        sourceWidth = origWidth
        sourceX = 0
        sourceHeight = origWidth
        sourceY = (origHeight - origWidth) / 2
      else
        sourceWidth = origHeight
        sourceX = (origWidth - origHeight) / 2
        sourceHeight = origHeight
        sourceY = 0

      EXIF.getData(origImage, =>
        orientation = EXIF.getTag(this, "Orientation")
#        logger.debug "orientation=#{orientation}"

        #draw image on canvas
        ctx = canvas.getContext("2d")
        @logTime "transformCoordinate"
        @transformCoordinate(canvas, maxWidth, maxHeight, orientation)
        @logTime "drawImageIOSFix"
        @drawImageIOSFix(ctx, origImage, sourceX, sourceY, sourceWidth, sourceHeight, 0, 0, maxWidth, maxHeight)
        @logTime "drawImageIOSFixComplete"
        dataURL = canvas.toDataURL(type, quality)
        @logTime "dataURLGenerated"

        # get the data from canvas as 70% jpg (or specified type).
        deferred.resolve(dataURL)
        return
      )

      deferred.promise


    createImage: (url, callback) ->
      @logTime("createImage")
      image = new Image()
      image.onload = -> callback(image)
      image.src = url

    doResizing: (url, options, callback) ->
      @createImage(url, (image) =>
        @logTime("preResizeImage")

        @resizeImage(image, options).then((dataURL) =>
          @logTime("postResizeImage")

          fromIdx = dataURL.indexOf(':')
          toIdx = dataURL.indexOf(';', fromIdx)

          mimeType = dataURL.substring(fromIdx + 1, toIdx)
          rawExt = mimeType.split('/').pop()
          resizedImage = {
            dataURL: dataURL,
            type: mimeType,
            ext: if rawExt == 'jpeg' then 'jpg' else 'png'
          }
          @logTime("callback")
          callback(resizedImage)
        )
      )

    ###
      URL to use in an image element
      options: {
          resizeMaxHeight or 300
          resizeMaxWidth or 250
          resizeQuality or 0.7
          resizeType: currently ignored and hard coded to jpg
      }
      callback -> callback that is sent the resized dataURL and mime type
    ###
    run: (url, options, callback) ->
      @startTime = Date.now()
      @doResizing(url, options, callback)
  }
)