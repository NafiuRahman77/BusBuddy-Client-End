time_list = [
    {
        "station": "36",
        "time": new Date("2024-01-30T14:35:00.669Z")
    },
    {
        "station": "37",
        "time": new Date("2024-01-30T14:45:23.670Z")
    },
    {
        "station": "38",
        "time": new Date("2024-01-30T14:49:23.653Z")
    },
    {
        "station": "39",
        "time": new Date("2024-01-30T14:52:25.664Z")
    },
    {
        "station": "40",
        "time": new Date("2024-01-30T15:17:08.177Z")
    },
    {
        "station": "70",
        "time": null
    }
];


let timeListStr = "{";
for (let i=0; i<time_list.length; i++) {
    if (time_list[i].time) 
        timeListStr += `"(${time_list[i].station}, \\\"${time_list[i].time.toISOString()}\\\")"`;
    else timeListStr += "null";
    if (i<time_list.length-1) timeListStr += ",";
};
timeListStr += "}";
console.log(timeListStr);