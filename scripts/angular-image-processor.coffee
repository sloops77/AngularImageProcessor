angular.module('tbImageProcessor', []).service('imageProcessor', ($q, $rootScope) ->
  {
  startTime: 0
  lastTime: 0

  _logTime: (methName) ->
    logger = if forge? then forge.logging else console
    @lastTime = Date.now()
    logger.log "@imageProcessor[#{@lastTime}]: #{methName} (#{@lastTime - @startTime})"

  ###
  Transform canvas coordination according to specified frame size and orientation
  Orientation value is from EXIF tag
  ###
  _transformCoordinate: (canvas, width, height, orientation) ->
    if orientation >= 5
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

  _detectVerticalSquash: (img) ->
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
  _drawImageIOSFix: (ctx, img, sx, sy, sw, sh, dx, dy, dw, dh) ->
    @_logTime "detectVerticalSquash"
    vertSquashRatio = @_detectVerticalSquash(img)
    @_logTime "drawImage"

    # Works only if whole image is displayed:
    # ctx.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh / vertSquashRatio);
    # The following works correct also when only a part of the image is displayed:
    ctx.drawImage(img, sx * vertSquashRatio, sy * vertSquashRatio, sw * vertSquashRatio, sh * vertSquashRatio, dx, dy, dw, dh)
    return

  _getResizeArea: ->
    resizeAreaId = "fileupload-resize-area"
    resizeArea = document.getElementById(resizeAreaId)
    unless resizeArea
      resizeArea = document.createElement("canvas")
      resizeArea.id = resizeAreaId
      resizeArea.style.visibility = "hidden"
      document.body.appendChild(resizeArea)
    resizeArea

#auto crops on height or width depending on the change in aspect ratio
  _scaleImage: (origImage, config) -> #fLetterBox
    sourceDims = {
      width              : 0
      height             : 0
      left               : 0
      top                : 0
      fScaleToTargetWidth : true
    }

    targetAR = config.width / config.height
    origAR = if config.orientation >= 5 then origImage.height / origImage.width else origImage.width / origImage.height
    @_logTime("AR: target=#{targetAR} origAR=#{origAR} origWidth=#{origImage.width} origHeight=#{origImage.height}")

    # figure out which dimension we take in full
    sourceDims.fScaleOnWidth = (targetAR > origAR)

    if sourceDims.fScaleOnWidth
      sourceDims.width = origImage.width
      sourceDims.height = Math.floor(if config.orientation >= 5 then targetAR * origImage.width else 1 / targetAR * origImage.width)
    else
      sourceDims.width = Math.floor(if config.orientation >= 5 then  1 / targetAR * origImage.height else targetAR * origImage.height)
      sourceDims.height = origImage.height

    sourceDims.left = Math.floor((origImage.width - sourceDims.width) / 2)
    sourceDims.top = Math.floor((origImage.height - sourceDims.height) / 2)
    sourceDims

  _doResizeImage: (origImage, config) ->
    type = 'image/jpeg' #config.resizeType or
    canvas = @_getResizeArea()
    canvas.width = config.width
    canvas.height = config.height

    sourceDims = @_scaleImage(origImage, config)

    #draw image on canvas
    ctx = canvas.getContext("2d")
    @_logTime "transformCoordinate"
    @_transformCoordinate(canvas, config.width, config.height, config.orientation)
    @_logTime "drawImageIOSFix"
    @_drawImageIOSFix(ctx, origImage, sourceDims.left, sourceDims.top, sourceDims.width, sourceDims.height, 0, 0, config.width, config.height)
    @_logTime "drawImageIOSFixComplete"
    dataURL = canvas.toDataURL(type, config.quality)
    @_logTime "dataURLGenerated"
    dataURL

  _createImage: (url, callback) ->
    @_logTime("_createImage")
    image = new Image()
    image.onload = -> callback(image)
    image.src = url

  createImageAndConfig: (url, options, callback) ->
    me = @
    parseVersions = (image, options, orientation) ->
      me._logTime("parseVersions")

      versions = [{
        width: options.width ? 150
        height: options.height ? 150
      }]

      #find closest aspect ratio for the image
      unless _.isEmpty(options.aspectRatios)
        arOptions = _(options.aspectRatios
        ).map((ratio) ->
          ratio.split(':')
        ).map((ratio) ->
          w = parseInt(ratio[0])
          h = parseInt(ratio[1])
          w/h
        ).value()

        origAR = if orientation >= 5 then image.height / image.width else image.width / image.height

        chosenAR = _.reduce(
          _.tail(arOptions),
          (closest, option) ->
            if Math.abs(option - origAR) < Math.abs(closest - origAR)
              option
            else
              closest
          _.head(arOptions)
        )

        versions = _.map(options.maxWidths, (maxWidth) ->
          if chosenAR > 1
            {
            maxWidth: maxWidth
            width: maxWidth
            height: 1/chosenAR * maxWidth
            }
          else
            {
            maxWidth: maxWidth
            width : chosenAR * maxWidth
            height: maxWidth
            }
        )

      versions

    @_createImage(url, (image) =>
      @_logTime("getEXIF")
      EXIF.getData(image, ->
        orientation = EXIF.getTag(this, "Orientation")
        me._logTime "orientation=#{orientation}"

        versions = parseVersions(image, options, orientation)
        _.each versions, (version) ->
          callback(image, _.extend(version, {quality: options.quality ? 0.7, orientation: orientation}))
      )
    )

  processImage: (image, config, onVersionStart, onVersionComplete) ->
    onVersionStart(config.maxWidth, config)

    dataURL = @_doResizeImage(image, config)
    @_logTime("afterResizeImage")

    fromIdx = dataURL.indexOf(':')
    toIdx = dataURL.indexOf(';', fromIdx)

    mimeType = dataURL.substring(fromIdx + 1, toIdx)
    rawExt = mimeType.split('/').pop()

    resizedImage = _.extend(config, {
      dataURL: dataURL
      type: mimeType
      ext: if rawExt == 'jpeg' then 'jpg' else 'png'
    })

    @_logTime("onVersionComplete")
    onVersionComplete(config.maxWidth, resizedImage)

  ###
    URL to use in an image element
    options: {
        height or 300
        width or 250
        quality or 0.7
    }
    callback -> callback that is sent the resized dataURL and mime type
  ###
  run: (url, options, onVersionStart, onVersionComplete) ->
    @startTime = Date.now()
    @_logTime("run(#{url}")
    @createImageAndConfig(url, options, (image, config) =>
      @processImage(image, config, onVersionStart, onVersionComplete)
    )
  }
)
