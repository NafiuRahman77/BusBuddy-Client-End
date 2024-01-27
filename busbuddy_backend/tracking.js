
const runningTrips = new Map();

class RunningTrip {
    id;
    start_timestamp;
    route;
    time_type;
    time_list = [];
    travel_direction;
    bus;
    is_default;
    bus_staff;
    approved_by;
    end_timestamp;
    start_location;
    end_location;
    path = [];
    passenger_count = 0;

    constructor (id, start_timestamp, route, time_type, 
                 travel_direction, bus, is_default,
                 bus_staff, approved_by, end_timestamp,
                 start_location, end_location, is_live) {
        this.id = id;
        this.start_timestamp = start_timestamp;
        this.route = route;
        this.time_type = time_type;
        this.travel_direction = travel_direction;
        this.bus = bus;
        this.is_default = is_default;
        this.bus_staff = bus_staff;
        this.approved_by = approved_by;
        this.end_timestamp = end_timestamp;
        this.start_location = start_location;
        this.end_location = end_location;
        this.time_list = [];
        this.path = [];
    };
};

module.exports = {RunningTrip, runningTrips}