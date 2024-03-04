
const { Readable } = require('stream');
const { finished } = require('stream/promises');
const streamToArray = require('stream-to-array');

trips = ["2656", "2610", "2662", "2665", "2670", "2673", "2676", "2680"]

const getTripData = async (trip_id) => {
    console.log(trip_id);
    let res = await fetch(`http://3.141.62.8:6969/api/getTripData`, {
    "headers": {
        "Content-Type": "application/json",
        // 'Content-Type': 'application/x-www-form-urlencoded',
        },
    "body": JSON.stringify({
        "trip_id" : trip_id,
    }),
    "method": "POST"
    });
    const body = await res.json();
    console.log(body);
};

const spam = async (trip_id) => {

    while (true) {
        for (let i=0; i<trips.length; i++) {
                await getTripData(trips[i]);
                setTimeout(() => {}, 1000);
        };
    };
};

spam();
// getTripData();