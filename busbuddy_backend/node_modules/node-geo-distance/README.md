wrapper for http://jsperf.com/vincenty-vs-haversine-distance-calculations,
all credit for code to author of that link




# Geo Distance formulas
[![Build Status](https://travis-ci.org/jaxgeller/node-geo-distance.svg)](https://travis-ci.org/jaxgeller/node-geo-distance)
+ Vincenty
+ Haversine






### Install
`$ npm install node-geo-distance --save`



### Use
```js
var geo = require('node-geo-distance');


--> {latitude:x, longitude:x}, {latitude:x, longitude:x}, callback(dist)
geo.vincenty(coord1, coord2, callback)

--> {latitude:x, longitude:x}, {latitude:x, longitude:x}
geo.vincentySync(coord1, coord2)



--> {latitude:x, longitude:x}, {latitude:x, longitude:x}, callback(dist)
geo.haversine(coord1, coord2, callback)

--> {latitude:x, longitude:x}, {latitude:x, longitude:x}
geo.haversineSync(coord1, coord2)
```

### Examples
```js
var geo = require('node-geo-distance');

// White house
var coord1 = {
  latitude: 38.8977330,
  longitude: -77.0365310
}

// Washington Monument
var coord2 = {
  latitude: 38.8894840,
  longitude: -77.0352790
}

geo.vincenty(coord1, coord2, function(dist) {
  console.log(dist);
});

var vincentyDist = geo.vincentySync(coord1, coord2);



geo.haversine(coord1, coord2, function(dist) {
  console.log(dist);
});

var haversineDist = geo.haversineSync(coord1, coord2);
```