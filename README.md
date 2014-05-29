AngularImageProcessor
=====================

Point and Shoot image processing for angular - desktop and mobile.

* Resizes, auto rotates, and auto crops using canvas.
* Currently tested on chrome, safari & ios

## Getting started

Include the module
```
angular.module('myApp', ['tbImageProcessor'])
```

Then in a controller or directive

```
angular.module('myApp').directive('filechooser', function(imageProcessor) {

  var processFile = function(file) {
    var options = {
      resizeMaxHeight: 150,
      resizeMaxWidth: 150,
      resizeQuality: 0.7
    };
    
    var url = URL.createObjectURL(file)
    
    imageProcessor.run(url, options, function(processedImage) {
      console.log(processedImage);
    });
  };
  
});
```

where processedImage is

```
{
  dataURL: "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD…x5C/ypM5B+VeOtFFa3MSe2mkjBMbtGf8AZNFFFaRbsZySuf/Z", 
  type: "image/jpeg", 
  ext: "jpg"
}
```
