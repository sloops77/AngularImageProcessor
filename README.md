AngularImageProcessor
=====================

Point and Shoot image processing for angular: 

auto rotates, auto crops and auto resizes using canvas.

```
options = {
  resizeMaxHeight: 150,
  resizeMaxWidth: 150,
  resizeQuality: 0.7
};

imageProcessor.run(url, options, function(resizedImage) {
  console.log(resizedImage);
});
```

Creates

```
{
  dataURL: "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD…x5C/ypM5B+VeOtFFa3MSe2mkjBMbtGf8AZNFFFaRbsZySuf/Z", 
  type: "image/jpeg", 
  ext: "jpg"
}
```
