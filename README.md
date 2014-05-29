AngularImageProcessor
=====================

Point and Shoot image processing for angular: 

Resizes, auto rotates, and auto crops using canvas.

```
options = {
  resizeMaxHeight: 150,
  resizeMaxWidth: 150,
  resizeQuality: 0.7
};

imageProcessor.run(url, options, function(processedImage) {
  console.log(processedImage);
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
