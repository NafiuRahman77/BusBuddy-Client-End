var assert = require('assert');

var geoDistance = require('../');

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

var expectedDistanceVincenty = 922.169;
var expectedDistanceHaversine = 923.625;

describe('Vincenty', function() {
  it('should be able to get distance between two points asynchronously', function(done) {
    geoDistance.vincenty(coord1, coord2, function(dist) {
      assert.equal(dist, expectedDistanceVincenty);
      done();
    })
  });

  it('should be able to get distance between two points synchronously', function(done) {
    assert.equal(geoDistance.vincentySync(coord1, coord2), expectedDistanceVincenty);
    done();
  });
});



describe('Haversine', function() {
  it('should be able to get distance between two points asynchronously', function(done) {
    geoDistance.haversine(coord1, coord2, function(dist) {
      assert.equal(dist, expectedDistanceHaversine);
      done();
    })
  });

  it('should be able to get distance between two points synchronously', function(done) {
    assert.equal(geoDistance.haversineSync(coord1, coord2), expectedDistanceHaversine);
    done();
  });
});