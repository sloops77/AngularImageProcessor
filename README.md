AngularImageProcessor
=====================

Point and Shoot image processing for angular: 

auto rotates, auto crops and auto resizes

```
options = {
  resizeMaxHeight: 150,
  resizeMaxWidth: 150,
  resizeQuality: 0.7
};
imageProcessor.run(url, options, function(resizedImage) {
            return $scope.image = {
              name: fileName,
              resized: resizedImage
            };
          });
```
