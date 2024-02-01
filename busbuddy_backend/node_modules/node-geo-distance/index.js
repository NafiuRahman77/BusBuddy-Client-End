Number.prototype.toRad = function() { return this * Math.PI / 180; }

exports.vincenty = function(coord1, coord2, callback) {
  var a = 6378137,
      b = 6356752.314245,
      f = 1 / 298.257223563;

  var lat1 = coord1.latitude;
  var lon1 = coord1.longitude;
  var lat2 = coord2.latitude;
  var lon2 = coord2.longitude;

  var L = (lon2 - lon1).toRad();
  var U1 = Math.atan((1 - f) * Math.tan(lat1.toRad()));
  var U2 = Math.atan((1 - f) * Math.tan(lat2.toRad()));

  var sinU1 = Math.sin(U1),
      cosU1 = Math.cos(U1);
  var sinU2 = Math.sin(U2),
      cosU2 = Math.cos(U2);

  var lambda = L,
      lambdaP, iterLimit = 100;
  do {
    var sinLambda = Math.sin(lambda),
        cosLambda = Math.cos(lambda);
    var sinSigma = Math.sqrt((cosU2 * sinLambda) * (cosU2 * sinLambda) + (cosU1 * sinU2 - sinU1 * cosU2 * cosLambda) * (cosU1 * sinU2 - sinU1 * cosU2 * cosLambda));
    if (sinSigma == 0) callback(0);
    var cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
    var sigma = Math.atan2(sinSigma, cosSigma);
    var sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma;
    var cosSqAlpha = 1 - sinAlpha * sinAlpha;
    var cos2SigmaM = cosSigma - 2 * sinU1 * sinU2 / cosSqAlpha;
    if (isNaN(cos2SigmaM)) cos2SigmaM = 0;
    var C = f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha));
    lambdaP = lambda;
    lambda = L + (1 - C) * f * sinAlpha * (sigma + C * sinSigma * (cos2SigmaM + C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)));
  } while (Math.abs(lambda - lambdaP) > 1e-12 && --iterLimit > 0);

  if (iterLimit == 0) callback(NaN);
  var uSq = cosSqAlpha * (a * a - b * b) / (b * b);
  var A = 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)));
  var B = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)));
  var deltaSigma = B * sinSigma * (cos2SigmaM + B / 4 * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) - B / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3 + 4 * cos2SigmaM * cos2SigmaM)));
  var s = b * A * (sigma - deltaSigma);

  s = s.toFixed(3);
  callback(s);
}

exports.vincentySync = function(coord1, coord2) {
  var a = 6378137,
      b = 6356752.314245,
      f = 1 / 298.257223563;

  var lat1 = coord1.latitude;
  var lon1 = coord1.longitude;
  var lat2 = coord2.latitude;
  var lon2 = coord2.longitude;

  var L = (lon2 - lon1).toRad();
  var U1 = Math.atan((1 - f) * Math.tan(lat1.toRad()));
  var U2 = Math.atan((1 - f) * Math.tan(lat2.toRad()));

  var sinU1 = Math.sin(U1),
      cosU1 = Math.cos(U1);
  var sinU2 = Math.sin(U2),
      cosU2 = Math.cos(U2);

  var lambda = L,
      lambdaP, iterLimit = 100;
  do {
    var sinLambda = Math.sin(lambda),
        cosLambda = Math.cos(lambda);
    var sinSigma = Math.sqrt((cosU2 * sinLambda) * (cosU2 * sinLambda) + (cosU1 * sinU2 - sinU1 * cosU2 * cosLambda) * (cosU1 * sinU2 - sinU1 * cosU2 * cosLambda));
    if (sinSigma == 0) return(0);
    var cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
    var sigma = Math.atan2(sinSigma, cosSigma);
    var sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma;
    var cosSqAlpha = 1 - sinAlpha * sinAlpha;
    var cos2SigmaM = cosSigma - 2 * sinU1 * sinU2 / cosSqAlpha;
    if (isNaN(cos2SigmaM)) cos2SigmaM = 0;
    var C = f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha));
    lambdaP = lambda;
    lambda = L + (1 - C) * f * sinAlpha * (sigma + C * sinSigma * (cos2SigmaM + C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)));
  } while (Math.abs(lambda - lambdaP) > 1e-12 && --iterLimit > 0);

  if (iterLimit == 0) return(NaN);
  var uSq = cosSqAlpha * (a * a - b * b) / (b * b);
  var A = 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)));
  var B = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)));
  var deltaSigma = B * sinSigma * (cos2SigmaM + B / 4 * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) - B / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3 + 4 * cos2SigmaM * cos2SigmaM)));
  var s = b * A * (sigma - deltaSigma);

  s = s.toFixed(3);
  return(s);
}

exports.haversine = function(coord1, coord2, callback) {
  var R = 6371;
  var lat1 = coord1.latitude;
  var lon1 = coord1.longitude;
  var lat2 = coord2.latitude;
  var lon2 = coord2.longitude;

  var dLat = (lat2 - lat1).toRad();
  var dLong = (lon2 - lon1).toRad();

  var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(lat1.toRad()) * Math.cos(lat2.toRad()) * Math.sin(dLong / 2) * Math.sin(dLong / 2);
  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  var d = R * c;

  return callback((d*1000).toFixed(3));
}

exports.haversineSync = function(coord1, coord2) {
  var R = 6371;
  var lat1 = coord1.latitude;
  var lon1 = coord1.longitude;
  var lat2 = coord2.latitude;
  var lon2 = coord2.longitude;

  var dLat = (lat2 - lat1).toRad();
  var dLong = (lon2 - lon1).toRad();

  var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(lat1.toRad()) * Math.cos(lat2.toRad()) * Math.sin(dLong / 2) * Math.sin(dLong / 2);
  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  var d = R * c;

  return (d*1000).toFixed(3);
}

