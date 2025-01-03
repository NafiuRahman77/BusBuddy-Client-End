const express = require('express');
const session = require('express-session');
const path = require('path');
// const cors = require('cors');
const app = express();
const port = 6969;
const bodyParser = require('body-parser');
const cookieParser = require('cookie-parser');
// const otpGenerator = require('otp-generator');
const dotenv = require('dotenv');
const url = require('url')
// const pdf = require("pdf-creator-node");
const fs = require("fs").promises;
const multer = require('multer');
// const html = fs.readFileSync("src/ticket.html", "utf8");
const { Readable } = require('stream');
const imageToBase64 = require('image-to-base64');
const geolib = require('geolib');
const tracking = require('./tracking.js');
const { createHttpTerminator } = require('http-terminator');
const bcrypt = require('bcryptjs');
const bcryptSaltRounds = 12;
const admin = require("firebase-admin");
const serviceAccount = require("./busbuddy-user-end-firebase-adminsdk.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const certPath = admin.credential.cert(serviceAccount);
const fcm = require("fcm-notification");
const FCM = new fcm (certPath);

const log4js = require("log4js");
log4js.configure({
    appenders: { 
        busbuddy: { type: "file", filename: "busbuddy.log", maxLogSize: 100000000 },
        console: { type: "stdout" },
    },
    categories: { 
        default: { appenders: ["busbuddy"], level: "debug" },
        all: { appenders: ["busbuddy", "console"], level: "info" },
        err: { appenders: ["busbuddy", "console"], level: "error" },
    },
});
const historyLogger = log4js.getLogger();
const consoleLogger = log4js.getLogger("all");
const errLogger = log4js.getLogger("err");
const readline = require('readline');

const reqLogger = (req, res, next) => {
    consoleLogger.info (`Req@ ${req.originalUrl} from ${req.session? (req.session.userid? req.session.userid : "") : "" } (${req.ip})`);
    next();
};

dotenv.config();

const { Pool, Client } = require('pg');
const dbconnObj = {
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASS,
    port: process.env.DB_PORT,
};
const dbclient = new Client(dbconnObj);
dbclient.connect();

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cookieParser());
app.enable('trust proxy');

// app.use(cors());
// app.use(cors({
//    origin: 'http://localhost:5173',
//    credentials: true
// }));
// const SSLCommerzPayment = require('sslcommerz-lts')
// const store_id = process.env.SSLCZ_STORE_ID;
// const store_passwd = process.env.SSLCZ_PASSWORD;
// const is_live = false;

app.use(session({
    store: new (require('connect-pg-simple')(session))({
        // Insert connect-pg-simple options here
        conObject: dbconnObj
    }),
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    sameSite: 'none',
    cookie: {
        maxAge: 30*24*60*60*1000,
        httpOnly: false
    }
}));

app.use(reqLogger);


const getRealISODate = () => {
    return (new Date(Date.now() - (new Date()).getTimezoneOffset() * 60000)).toISOString().substring(0, 10);
};


dbclient.query(
    `select *, array_to_json(time_list) as list_time from trip where is_live=true`
).then(qres2 => {
    //consoleLogger.info(qres2.rows[0].start_location);
    qres2.rows.forEach(td => {
        let newTrip = new tracking.RunningTrip 
            (td.id, td.start_timestamp, td.route, td.time_type, 
            td.travel_direction, td.bus, td.is_default,
            td.driver, td.helper, td.approved_by, td.end_timestamp,
            {   
                latitude: td.start_location.x.toString(), 
                longitude: td.start_location.y.toString(),
            }, 
            td.end_location);
        // td.list_time.forEach (async tp =>  {
        //     // newTrip.time_list.push({...tp});
        //     newTrip.time_list.push({
        //         station: tp.station,
        //         time: (tp.time == "1970-01-01T06:00:00+06:00")? null : new Date(tp.time),
        //     });
        // });
        if (td.travel_direction == "to_buet") {
            for (let i=0; i<td.list_time.length; i++) {
                historyLogger.debug (td.list_time[i]);
                newTrip.time_list.push({
                    station: td.list_time[i].station,
                    time: (td.list_time[i].time == "1970-01-01T06:00:00+06:00")? null : new Date(td.list_time[i].time),
                });
            };
        } else if (td.travel_direction == "from_buet") {
            for (let i=td.list_time.length-1; i>=0; i--) {
                historyLogger.debug (td.list_time[i]);
                newTrip.time_list.push({
                    station: td.list_time[i].station,
                    time: (td.list_time[i].time == "1970-01-01T06:00:00+06:00")? null : new Date(td.list_time[i].time),
                });
            };
        };
        if (td.path) td.path.forEach (async p =>  {
            // newTrip.time_list.push({...tp});
            newTrip.path.push({
                latitude: p.x.toString(),
                longitude: p.y.toString(),
            });
        });
        newTrip.passenger_count = td.passenger_count;
        if (td.time_window) {
            consoleLogger.info(td.time_window);
            newTrip.time_window = [...td.time_window];
        };
        tracking.runningTrips.set (newTrip.id, newTrip);
        tracking.busStaffMap.set (newTrip.driver, newTrip.id);
        tracking.busStaffMap.set (newTrip.helper, newTrip.id);
    });
}).catch(e => errLogger.error(e.stack));

dbclient.query("SELECT id, coords FROM station").then(qres => {
    // consoleLogger.info(qres.rows);
    qres.rows.forEach( (st)  =>  {
        tracking.stationCoords.set(st.id, {
            latitude: st.coords.x,
            longitude: st.coords.y,
        });
    });
    // consoleLogger.info(tracking.stationCoords);
}).catch(e => errLogger.error(e.stack));

dbclient.query("SELECT id, name FROM station").then(qres => {
    // consoleLogger.info(qres.rows);
    qres.rows.forEach( (st)  =>  {
        tracking.stationNames.set(st.id, st.name);
    });
    // consoleLogger.info(tracking.stationCoords);
}).catch(e => errLogger.error(e.stack));

dbclient.query("SELECT id, terminal_point FROM route").then(qres => {
    // consoleLogger.info(qres.rows);
    qres.rows.forEach( (r)  =>  {
        tracking.routeNames.set(r.id, r.terminal_point);
    });
    // consoleLogger.info(tracking.stationCoords);
}).catch(e => errLogger.error(e.stack));

app.post('/api/login', (req, res) => {
    // consoleLogger.info(req.body);
    dbclient.query(
        `SELECT name, password FROM student WHERE id=$1`, [req.body.id]
    ).then (async qres => {
        // consoleLogger.info(qres);
        if (qres.rows.length === 0) {
            dbclient.query(
                `SELECT name, password FROM buet_staff WHERE id=$1`, [req.body.id]
            ).then (async qres2 => {
                // consoleLogger.info(qres);
                if (qres2.rows.length === 0) {
                    dbclient.query(
                        `SELECT name, password, role FROM bus_staff WHERE id=$1`, [req.body.id]
                    ).then (async qres3 => {
                        historyLogger.debug(qres3);
                        if (qres3.rows.length === 0) {
                            res.send({ 
                                success: false,
                                name: null,
                                relogin: false
                            });
                        } else {
                            let verif = await bcrypt.compare (req.body.password, qres3.rows[0].password);
                            if (verif === true) {
                                dbclient.query(
                                    `select sid from session where sess->>'userid'= $1`, [req.body.id]
                                ).then(qres4 => {
                                    historyLogger.debug(qres4);
                                    let relogin = false;
                                    if (qres4.rows.length > 0) {
                                        req.sessionStore.destroy(qres4.rows[0].sid);
                                        relogin = true;
                                    };
                                    req.session.userid = req.body.id;
                                    req.session.user_type = "bus_staff";
                                    req.session.bus_role = qres3.rows[0].role;
                                    req.session.fcm_id = req.body.fcm_id;
                                    res.send({
                                        success: true,
                                        name: qres3.rows[0].name,
                                        user_type: "bus_staff",
                                        relogin: relogin,
                                        bus_role: qres3.rows[0].role,
                                    });
                                    consoleLogger.info(req.session);
                                }).catch(e => errLogger.error(e.stack));
                            } else {
                                res.send({ 
                                    success: false,
                                    name: null,
                                    relogin: false
                                });
                            };
                        };
                    }).catch(e => errLogger.error(e.stack));
                } else {
                    let verif = await bcrypt.compare (req.body.password, qres2.rows[0].password);
                    if (verif === true) {
                        req.session.userid = req.body.id;
                        req.session.user_type = "buet_staff";
                        req.session.fcm_id = req.body.fcm_id;
                        res.send({
                            success: true,
                            name: qres2.rows[0].name,
                            user_type: "buet_staff"
                        });
                        consoleLogger.info(req.session);
                    } else {
                        res.send({ 
                            success: false,
                            name: null,
                            relogin: false
                        });
                    };
                };
            }).catch(e => errLogger.error(e.stack));
        } else {
            let verif = await bcrypt.compare (req.body.password, qres.rows[0].password);
            if (verif === true) {
                req.session.userid = req.body.id;
                req.session.user_type = "student";
                req.session.fcm_id = req.body.fcm_id;
                res.send({
                    success: true,
                    name: qres.rows[0].name,
                    user_type: "student"
                });
                consoleLogger.info(req.session);
            } else {
                res.send({ 
                    success: false,
                    name: null,
                    relogin: false
                });
            };
        };
    }).catch(e => errLogger.error(e.stack));
});

app.post('/api/sessionCheck', (req, res) => {
    if (req.session.userid) {
        req.session.fcm_id = req.body.fcm_id;
        res.send({
            recognized: true,
            relogin: false,
            user_type: req.session.user_type,
            user_id: req.session.userid,
            bus_role: req.session.bus_role,
        });
    } else {
        res.send({
            recognized: false,
            relogin: false,
        });
    };
});

// app.post('/api/adminLogin', (req, res) => {
//     consoleLogger.info(req.body);
//     dbclient.query(
//         `SELECT name FROM admin WHERE id=$1 AND password=$2`,
//         [req.body.id, req.body.password]
//     ).then(qres => {
//         //consoleLogger.info(qres);
//         if (qres.rows.length === 0) res.send({ 
//             success: false,
//             name: null,
//         });
//         else {
//             req.session.adminid = req.body.id;
//             res.send({
//                 success: true,
//                 name: qres.rows[0].name,
//                 admin: true
//             });
//             consoleLogger.info(req.session);
//         };
//     }).catch(e => errLogger.error(e.stack));
// });

app.post('/api/logout',(req,res) => {
    req.session.destroy();
    res.send({
        success: true
    });
});

app.post('/api/getProfile', (req, res) => {
    historyLogger.debug(req.session);
    if (req.session.userid) {
        if (req.session.user_type == "student") {
            dbclient.query(
                `select s.id as id, s.name as name, phone, email, default_route, 
                 r.terminal_point as default_route_name, default_station, st.name as default_station_name
                 from student as s, route as r, station as st 
                 where s.id=$1 and s.default_route=r.id and s.default_station=st.id`, 
                [req.session.userid]
            ).then(qres => {
                //consoleLogger.info(qres);
                if (qres.rows.length === 0) res.send({ 
                    success: false,
                });
                else {
                    res.send({
                        ...qres.rows[0],
                        success: true,
                    });
                };
            }).catch(e => errLogger.error(e.stack));
        } else if (req.session.user_type == "buet_staff") {
            dbclient.query(
                `select id, name, phone, department, designation, residence from buet_staff where id=$1`,
                [req.session.userid]
            ).then(qres => {
                //consoleLogger.info(qres);
                if (qres.rows.length === 0) res.send({ 
                    success: false,
                });
                else {
                    res.send({
                        ...qres.rows[0],
                        success: true,
                    });
                };
            }).catch(e => errLogger.error(e.stack));
        } else if (req.session.user_type == "bus_staff") {
            dbclient.query(
                `select id, name, phone, role from bus_staff where id=$1`,
                [req.session.userid]
            ).then(qres => {
                //consoleLogger.info(qres);
                if (qres.rows.length === 0) res.send({ 
                    success: false,
                });
                else {
                    res.send({
                        ...qres.rows[0],
                        success: true,
                    });
                };
            }).catch(e => errLogger.error(e.stack));
        };
    };
});

app.post('/api/getProfileStatic', (req, res) => {
    // consoleLogger.info(req);
    if (req.session.userid) {
        if (req.session.user_type == "student" || req.session.user_type == "buet_staff" || req.session.user_type == "bus_staff") {
            dbclient.query(
                `select id, name from ${dbclient.escapeIdentifier(req.session.user_type)} where id=$1`, 
                [req.session.userid]
            ).then (async qres => {
                historyLogger.debug(qres);
                if (qres.rows.length === 0) {
                    res.send({ 
                        success: false,
                    });
                } else {
                    let response = "";
                    try {
                        let data = await fs.readFile("../../busbuddy_storage/" + req.session.userid);
                        response = data.toString('base64');
                    } catch (e) {
                        if (e.code != 'ENOENT') errLogger.error(e);
                    };
                    res.send({
                        ...qres.rows[0],
                        success: true,
                        imageStr: response,
                    });
                };
            }).catch(e => errLogger.error(e.stack));
        } else consoleLogger.info("Session not recognised.")
    };
});

app.post('/api/updatePassword', (req, res) => {
    // consoleLogger.info(req);
    if (req.session.userid) {
        if (req.session.user_type == "student" || req.session.user_type == "buet_staff" || req.session.user_type == "bus_staff") {
            dbclient.query(
                `select id, password from ${dbclient.escapeIdentifier(req.session.user_type)} where id=$1`, 
                [req.session.userid]
            ).then (async qres => {
                historyLogger.debug(qres);
                if (qres.rows.length === 0) {
                    res.send({ 
                        success: false,
                    });
                } else {
                    let verif = await bcrypt.compare (req.body.old, qres.rows[0].password);
                    if (verif === true) {
                        let newHash = await bcrypt.hash (req.body.new, bcryptSaltRounds);
                        dbclient.query(
                            `update ${dbclient.escapeIdentifier(req.session.user_type)} 
                             set password=$1 where id=$2 and password=$3`, 
                            [newHash, req.session.userid, qres.rows[0].password]
                        ).then (async qres2 => {
                            historyLogger.debug(qres2);
                            if (qres2.rowCount === 1) {
                                res.send({ 
                                    success: true,
                                });
                            } else {
                                res.send({ 
                                    success: false,
                                });
                            };
                        }).catch(e => errLogger.error(e.stack));
                    } else {
                        res.send({ 
                            success: false,
                        });
                    };
                };
            }).catch(e => errLogger.error(e.stack));
        } else consoleLogger.info("Session not recognised.")
    };
});

app.post('/api/getDefaultRoute', (req, res) => {
    historyLogger.debug(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select default_route, r.terminal_point as default_route_name 
            from student as s, route as r where s.id=$1 and s.default_route=r.id`, 
            [req.session.userid]
        ).then(qres => {
            //consoleLogger.info(qres);
            if (qres.rows.length === 0) res.send({ 
                success: false,
            });
            else {
                res.send({
                    ...qres.rows[0],
                    success: true,
                });
            };
        }).catch(e => errLogger.error(e.stack));
    };
});     

app.post('/api/updateProfile', (req,res) => {
    historyLogger.debug(req.body);
    if (req.session.userid === req.body.id) {
        if (req.session.user_type == "student") {
            dbclient.query(
                `UPDATE student SET phone=$1, email=$2, default_route=$3, default_station=$4 WHERE id=$5`, 
                [req.body.phone, req.body.email, req.body.default_route, req.body.default_station, req.body.id]
            ).then(qres => {
                historyLogger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => errLogger.error(e.stack));
        } else if (req.session.user_type == "buet_staff") {
            dbclient.query(
                `UPDATE buet_staff SET phone=$1, residence=$2 WHERE id=$3`, 
                [req.body.phone, req.body.residence, req.body.id]
            ).then(qres => {
                historyLogger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => errLogger.error(e.stack));
        } else if (req.session.user_type == "bus_staff") {
            dbclient.query(
                `UPDATE bus_staff SET phone=$1 WHERE id=$2`, 
                [req.body.phone, req.body.id]
            ).then(qres => {
                historyLogger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => errLogger.error(e.stack));
        } 
    };
});

app.post('/api/getRoutes', (req,res) => {
    dbclient.query("SELECT id, terminal_point FROM route").then(qres => {
        res.send(qres.rows);
    }).catch(e => errLogger.error(e.stack));
});

app.post('/api/getStations', (req,res) => {
    dbclient.query("SELECT id, name, coords FROM station").then(qres => {
        res.send(qres.rows);
    }).catch(e => errLogger.error(e.stack));
});

app.post('/api/getRouteStations', (req,res) => {
    dbclient.query("SELECT id, name FROM station where id in (select unnest(points) from route where id = $1)",
		   [ req.body.route]).then(qres => {
        res.send(qres.rows);
    }).catch(e => errLogger.error(e.stack));
});

app.post('/api/getBusStaffData', (req,res) => {
    if (req.session && req.session.user_type == "buet_staff") {
        dbclient.query("SELECT id, name, phone from bus_staff").then(qres => {
            res.send(qres.rows);
        }).catch(e => errLogger.error(e.stack));
    };
});

app.post('/api/getBusList', (req,res) => {
    if (req.session && req.session.user_type == "bus_staff") {
        dbclient.query("select distinct bus from allocation where driver=$1 or helper=$1",
        [req.session.userid]).then(qres => {
            res.send(qres.rows);
        }).catch(e => errLogger.error(e.stack));
    };
});


app.post('/api/addFeedback', (req,res) => {
    historyLogger.debug(req.body);
    if (req.session.userid) {
        if (req.session.user_type == "student") {
            dbclient.query(
                `INSERT INTO student_feedback (complainer_id, route, submission_timestamp, concerned_timestamp, text, subject) 
                 values ($1, $2, NOW(), $3, $4, $5)`, 
                [req.session.userid, req.body.route==""? null:req.body.route, 
                req.body.timestamp==""? null:req.body.timestamp, req.body.text, JSON.parse(req.body.subject)]
            ).then(qres => {
                historyLogger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => errLogger.error(e.stack));
        } else if (req.session.user_type == "buet_staff") {
            dbclient.query(
                `INSERT INTO buet_staff_feedback (complainer_id, route, submission_timestamp, concerned_timestamp, text, subject) 
                 values ($1, $2, NOW(), $3, $4, $5)`, 
                [req.session.userid, req.body.route==""? null:req.body.route, 
                req.body.timestamp==""? null:req.body.timestamp, req.body.text, JSON.parse(req.body.subject)]
            ).then(qres => {
                historyLogger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => errLogger.error(e.stack));
        };
    };
});

app.post('/api/addRequisition', (req,res) => {
    consoleLogger.info(req.body);
    if (req.session.userid) {
        dbclient.query(
            `INSERT INTO requisition (requestor_id, destination, bus_type, subject, text, timestamp, source) 
             values ($1, $2, $3, $4, $5, $6, $7)`, 
            [req.session.userid, req.body.destination, JSON.parse(req.body.bus_type), 
                req.body.subject, req.body.text, req.body.timestamp, req.body.source]
        ).then(qres => {
            historyLogger.debug(qres);
            if (qres.rowCount === 1) res.send({ 
                success: true,
            });
            else if (qres.rowCount === 0) {
                res.send({
                    success: false,
                });
            };
        }).catch(e => errLogger.error(e.stack));
    };
});

app.post('/api/addRepairRequest', (req,res) => {
    consoleLogger.info(req.body);
    if (req.session.userid && req.session.user_type=="bus_staff") {
        dbclient.query(
            `INSERT INTO repair (requestor, bus, parts, request_des, repair_des, timestamp) 
             values ($1, $2, $3, $4, $5, current_timestamp)`, 
            [req.session.userid, req.body.bus, req.body.parts, req.body.request_des, req.body.repair_des]
        ).then(qres => {
            historyLogger.debug(qres);
            if (qres.rowCount === 1) res.send({ 
                success: true,
            });
            else if (qres.rowCount === 0) {
                res.send({
                    success: false,
                });
            };
        }).catch(e => errLogger.error(e.stack));
    };
});

app.post('/api/purchaseTickets', (req,res) => {
    if (req.session.userid) {
        dbclient.query(
            `CALL make_purchase($1, $2, $3, $4)`, 
            [req.session.userid, req.body.method, req.body.trxid, req.body.count]
        ).then(qres => {
            historyLogger.debug(qres);
            dbclient.query(
                `select * from purchase where trxid=$1`, 
                [req.body.trxid]
            ).then(qres => {
                historyLogger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => errLogger.error(e.stack));
        }).catch(e => errLogger.error(e.stack));
    };
});

app.post('/api/getTicketCount', (req,res) => {
    // consoleLogger.info(req.body);
    if (req.session.userid) {
        dbclient.query(
            `select count(*) from ticket where student_id=$1 and is_used = false`, 
            [req.session.userid]
        ).then(qres => {
            historyLogger.debug(qres);
            if (qres.rowCount === 1) res.send({ 
                success: true,
                count: qres.rows[0].count,
            });
            else if (qres.rowCount === 0) {
                res.send({
                    success: false,
                });
            };
        }).catch(e => errLogger.error(e.stack));
    };
});

app.post('/api/getTicketQRData', (req,res) => {
    if (req.session.userid && req.session.user_type=="student") {
        dbclient.query(
            `select id from ticket where student_id=$1 and is_used=false limit 1`, 
            [req.session.userid]
        ).then(qres => {
            historyLogger.debug(qres);
            if (qres.rowCount === 1) 
            res.send({ 
                success: true,
                ticket_id: qres.rows[0].id,
            });
            else if (qres.rowCount === 0) {
                res.send({
                    success: false,
                });
            };
        }).catch(e => errLogger.error(e.stack));
    };
});

app.post('/api/getTicketList', (req,res) => {
    // consoleLogger.info(req.body);
    if (req.session.userid && req.session.user_type=="student") {
        dbclient.query(
            `select id from ticket where student_id=$1 and is_used=false order by student_id limit 5`, 
            [req.session.userid]
        ).then(qres => {
            historyLogger.debug(qres);
            if (qres.rows.length > 0) {
                let list = [];
                for (let i=0 ; i< qres.rows.length; i++) {
                    list.push (qres.rows[i].id);
                };
                res.send({ 
                    success: true,
                    ticket_list: [...list],
                });
            } else {
                res.send({
                    success: false,
                });
            };
        }).catch(e => errLogger.error(e.stack));
    };
});

app.post('/api/getUserFeedback', (req, res) => {
    historyLogger.debug(req.session);
    if (req.session.userid) {
        if (req.session.user_type == "student") {
            dbclient.query(
            `select f.*, r.terminal_point as route_name
            from student_feedback as f, public.route as r 
            where f.route = r.id and f.complainer_id = $1`, [req.session.userid]
            ).then(qres => {
                historyLogger.debug(qres);
                res.send(qres.rows);
            }).catch(e => {
                errLogger.error(e.stack);
                res.send({ 
                    success: false,
                });
            });
        } else if (req.session.user_type == "buet_staff") {
            dbclient.query(
            `select f.*, r.terminal_point as route_name
            from buet_staff_feedback as f, public.route as r 
            where f.route = r.id and f.complainer_id = $1`, [req.session.userid]
            ).then(qres => {
                historyLogger.debug(qres);
                res.send(qres.rows);
            }).catch(e => {
                errLogger.error(e.stack);
                res.send({ 
                    success: false,
                });
            });
        } 
    };
});

app.post('/api/getUserRequisition', (req, res) => {
    historyLogger.debug(req.session);
    if (req.session.userid) {
        dbclient.query(
           `
           select r.*, a.driver, a.helper, a.bus from requisition r, allocation a 
           where r.requestor_id = $1 and (a.id = r.allocation_id )
           union
           select *, null as driver, null as helper, null as bus from requisition 
           where requestor_id=$1 and allocation_id is null`, [req.session.userid]
        ).then(qres => {
            historyLogger.debug(qres);
            res.send(qres.rows);
        }).catch(e => {
            errLogger.error(e.stack);
            res.send({ 
                success: false,
            });
        });
    };
});

app.post('/api/getRepairRequests', (req, res) => {
    historyLogger.debug(req.session);
    if (req.session.userid && req.session.user_type=="bus_staff") {
        dbclient.query(
           `select * from repair where requestor = $1`, [req.session.userid]
        ).then(qres => {
            historyLogger.debug(qres);
            res.send(qres.rows);
        }).catch(e => {
            errLogger.error(e.stack);
            res.send({ 
                success: false,
            });
        });
    };
});

app.post('/api/getUserPurchaseHistory', (req, res) => {
    historyLogger.debug(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select * from purchase where buyer_id=$1`, [req.session.userid]
        ).then(qres => {
            //log(qres);
            res.send(qres.rows);
        }).catch(e => {
            errLogger.error(e.stack);
            res.send({ 
                success: false,
            });
        });
    };
});

app.post('/api/getTicketUsageHistory', (req, res) => {
    historyLogger.debug(req.session);
    if (req.session.userid && req.session.user_type == 'student') {
        dbclient.query(
            `select tk.trip_id, tr.route, tr.start_timestamp, tr.travel_direction, 
            tr.bus, tk.scanned_by from ticket tk, trip tr where tk.is_used = true 
            and tk.trip_id = tr.id and tk.student_id=$1 order by tr.start_timestamp desc`, [req.session.userid]
        ).then(qres => {
            //log(qres);
            res.send(qres.rows);
        }).catch(e => {
            errLogger.error(e.stack);
            res.send({ 
                success: false,
            });
        });
    };
});


app.post('/api/getRouteTimeData', (req, res) => {
    historyLogger.debug(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select lpad(id::varchar, 8, '0') as id, start_timestamp, route, array_to_json(time_list), bus,
             driver, helper from allocation where route=$1`, [req.body.route]
        ).then(qres => {
	    let list = [...qres.rows];
	    //list.forEach(trip => {
	//	trip.time_list = JSON.parse(trip.timeList);
	  //  });
            historyLogger.debug(list);
            res.send(qres.rows);
        }).catch(e => {
            errLogger.error(e.stack);
            res.send({ 
                success: false,
            });
        });
    };
});

app.post('/api/getTrackingData', async (req, res) => {
    historyLogger.debug(req.session);
    if (req.session.userid) {
	    let list = [];
        //iterating over map
        tracking.runningTrips.forEach( async trip => {
            if (trip.route == req.body.route) list.push (trip);
        });
        historyLogger.debug(list);
        res.send(list);
    };
});

// app.post('/api/sendRepairRequest', (req,res) => {
//     
//     consoleLogger.info(req.body);
//     res.send({
//         success: true,
//     });
// });

// app.post('/api/getRepairRequest', (req,res) => {
//     
//     consoleLogger.info(req.body);
//     res.send({
//         success: true,
//         data: [
//             {
//                 id: 1,
//                 staff_id: "altaf",
//                 item : "Engine",
//                 item_count: "1",
//                 problem: "Engine problem",
//                 status: "pending",
//                 timestamp: "2021-05-01 12:00:00"
//             },
//             {
//                 id: 2,
//                 staff_id: "altaf",
//                 item : "Engine",
//                 item_count: "1",
//                 problem: "Engine problem",
//                 status: "pending",
//                 timestamp: "2021-05-01 12:00:00"
//             },
//             {
//                 id: 3,
//                 staff_id: "altaf",
//                 item : "Engine",
//                 item_count: "1",
//                 problem: "Engine problem",
//                 status: "pending",
//                 timestamp: "2021-05-01 12:00:00"
//             },
//             {
//                 id: 4,
//                 staff_id: "altaf",
//                 item : "Engine",
//                 item_count: "1",
//                 problem: "Engine problem",
//                 status: "pending",
//                 timestamp: "2021-05-01 12:00:00"
//             },
           
//         ]
//     });
// }
// );
app.post('/api/getNotifications', (req,res) => {
    let notifs = [];
    dbclient.query(
        `select * from broadcast_notification order by timestamp desc limit 10`
    ).then(qres => {
        let broadcast = [...qres.rows];
        for (let i=0; i<broadcast.length; i++) broadcast[i].type = 'broadcast';
        notifs = [...broadcast];
        dbclient.query(
            `select * from personal_notification where user_id=$1 order by timestamp desc limit 10`, 
            [req.session.userid]
        ).then(qres2 => {
            let personal = [...qres2.rows];
            for (let i=0; i<personal.length; i++) personal[i].type = 'personal';
            notifs = [...notifs, ...personal];
            res.send(notifs);
        }).catch(e => {
            errLogger.error(e.stack);
            res.send({ 
                success: false,
            });
        });
    }).catch(e => {
        errLogger.error(e.stack);
        res.send({ 
            success: false,
        });
    });
});

// // Teacher bill payment api
// app.post('/api/payBill', (req,res) => {
//     
//     consoleLogger.info(req.body);
//     res.send({
//         success: true,
//         payment_id: 1984983210
//     });
// });

// // Teacher bill history api
// app.post('/api/getBillHistory', (req,res) => {
//     
//     consoleLogger.info(req.body);
//     res.send({
//         success: true,
//         data: [
//             {
//                 id: 1,
//                 teacher_id: "mtzcse",
//                 name: "Md. Toufikuzzaman",
//                 bill_type: "Monthly",
//                 bill_amount: "200",
//                 bill_month: "January",
//                 bill_year: "2024",
//                 timestamp: "2021-05-01 12:00:00"
//             },       
           
//         ]
//     });
// });

//get route details
//get nearest station
app.post('/api/getNearestStation', (req,res) => {
    
    consoleLogger.info(req.body);
    let minDist = 1000000, nearestId, nearestCoord;
    tracking.stationCoords.forEach( async (st, st_id) => {
        let dist = geolib.getDistance(st, {
            latitude: req.body.latitude,
            longitude: req.body.longitude,
        });
        if (dist < minDist) {
            minDist = dist;
            nearestId = st_id;
            nearestCoord = {...st};
        };
    });
    res.send({
        station_id: nearestId,
        station_coordinates: nearestCoord,
    });
});

// app.post('/api/getRouteFromStation', (req,res) => {
//     
//     consoleLogger.info(req.body);
//     res.send([
//     {"id":"00000451","start_timestamp":"2023-09-11T00:40:00.000Z","route":"3","array_to_json":[{"station":"17","time":"2023-09-11T06:40:00+06:00"},{"station":"18","time":"2023-09-11T06:42:00+06:00"},{"station":"19","time":"2023-09-11T06:44:00+06:00"},{"station":"20","time":"2023-09-11T06:46:00+06:00"},{"station":"21","time":"2023-09-11T06:48:00+06:00"},{"station":"22","time":"2023-09-11T06:50:00+06:00"},{"station":"23","time":"2023-09-11T06:52:00+06:00"},{"station":"24","time":"2023-09-11T06:54:00+06:00"},{"station":"25","time":"2023-09-11T06:57:00+06:00"},{"station":"26","time":"2023-09-11T07:00:00+06:00"},{"station":"70","time":"2023-09-11T07:15:00+06:00"}],"bus":"Ba-24-8518"},
//     {"id":"00000452","start_timestamp":"2023-09-11T07:40:00.000Z","route":"3","array_to_json":[{"station":"70","time":"2023-09-11T13:40:00+06:00"},{"station":"26","time":"2023-09-11T13:55:00+06:00"},{"station":"25","time":"2023-09-11T13:58:00+06:00"},{"station":"24","time":"2023-09-11T14:00:00+06:00"},{"station":"23","time":"2023-09-11T14:02:00+06:00"},{"station":"22","time":"2023-09-11T14:04:00+06:00"},{"station":"21","time":"2023-09-11T14:06:00+06:00"},{"station":"20","time":"2023-09-11T14:08:00+06:00"},{"station":"19","time":"2023-09-11T14:10:00+06:00"},{"station":"18","time":"2023-09-11T14:12:00+06:00"},{"station":"17","time":"2023-09-11T14:14:00+06:00"}],"bus":"Ba-24-8518"},]);
// });

//get trip data
app.post('/api/getTripData', (req,res) => {
    consoleLogger.info(req.body);
    res.send({
        success: true,
        ...tracking.runningTrips.get(req.body.trip_id),
    });
});

app.post('/api/checkStaffRunningTrip', async (req,res) => {
    // consoleLogger.info(req.body);
    if (req.session.userid && req.session.user_type=="bus_staff") {
        let t_id = await tracking.busStaffMap.get(req.session.userid);
        let trip = await tracking.runningTrips.get(t_id);
        if (trip) res.send({
            success: true,
            ...trip,
        });
        else res.send({
            success: false,
        });
    };
});
    
  
//get trip data
app.post('/api/getStaffTrips', (req,res) => {
    if (req.session.userid && req.session.user_type=="bus_staff") {
        // consoleLogger.info(req.body);
        dbclient.query(
            `select * from allocation where is_done=false and (driver=$1 or helper=$1) order by start_timestamp asc`, 
            [req.session.userid]
        ).then(qres => {
            historyLogger.debug(qres);
            dbclient.query(
                `select * from trip where (driver=$1 or helper=$1) order by start_timestamp desc`, 
                [req.session.userid]
            ).then(qres2 => {
                historyLogger.debug(qres2);
                if (qres.rows.length === 0 && qres2.rows.length === 0) {
                    res.send({
                        success: false,
                    });
                } else {
                    res.send({
                        success: true,
                        upcoming: [...qres.rows],
                        actual: [...qres2.rows]
                    });
                };
            }).catch(e => errLogger.error(e.stack));
        }).catch(e => errLogger.error(e.stack));
    };
});

app.post('/api/startTrip', (req,res) => {
    consoleLogger.info(req.body);
    if (req.session.userid && req.session.user_type=="bus_staff" && req.session.bus_role=="driver") {
        let ronin = tracking.busStaffMap.has(req.session.userid);
        if (!ronin) {
            dbclient.query(
                `call initiate_trip2($1, $2, $3)`, 
                [req.body.trip_id, req.session.userid, ('('+req.body.latitude+','+req.body.longitude+')')]
            ).then(qres => {
                // historyLogger.debug(qres);
                dbclient.query(
                    `select *, array_to_json(time_list) as list_time from trip where id=$1`, 
                    [req.body.trip_id]
                ).then (async qres2 => {
                    // historyLogger.debug(qres2);
                    if (qres2.rows.length == 1) {
                        let td = {...qres2.rows[0]};
                        historyLogger.debug(td.list_time);
                        let newTrip = new tracking.RunningTrip 
                        (td.id, td.start_timestamp, td.route, td.time_type, 
                            td.travel_direction, td.bus, td.is_default,
                            td.driver, td.helper, td.approved_by, td.end_timestamp,
                            {   
                                latitude: req.body.latitude, 
                                longitude: req.body.longitude
                            }, 
                            td.end_location);
                        // td.list_time.forEach (async tp =>  {
                        //     // newTrip.time_list.push({...tp});
                        //     newTrip.time_list.push({
                        //         station: tp.station,
                        //         time: null
                        //     });
                        // });
                        newTrip.path.push (newTrip.start_location);
                        newTrip.time_window.push (newTrip.start_timestamp);
                        if (td.travel_direction == "to_buet") {
                            for (let i=0; i<td.list_time.length; i++) {
                                newTrip.time_list.push({
                                    station: td.list_time[i].station,
                                    time: null
                                });
                            }
                        } else if (td.travel_direction == "from_buet") {
                            for (let i=td.list_time.length-1; i>=0; i--) {
                                newTrip.time_list.push({
                                    station: td.list_time[i].station,
                                    time: null
                                });
                            };
                        };
                        tracking.runningTrips.set (newTrip.id, newTrip);
                        tracking.busStaffMap.set (newTrip.driver, newTrip.id);
                        tracking.busStaffMap.set (newTrip.helper, newTrip.id);

                        res.send({ 
                            success: true,
                            ...tracking.runningTrips.get(newTrip.id),
                        });

                        let notif_list;  
                        // consoleLogger.info("trying to get list for notif");
                        dbclient.query(
                            `select array(select distinct s.sess->>'fcm_id' from session s, student st 
                            where st.id=sess->>'userid' and s.sess->>'fcm_id' is not null and st.default_route=$1)`, [newTrip.route]
                        ).then(qres3 => {
                            historyLogger.debug(qres3);
                            notif_list = [...qres3.rows[0].array];
                            if (notif_list) {
                                consoleLogger.info(notif_list);
                                let message = {
                                    // data: {
                                    //   score: '850',
                                    //   time: '2:45'
                                    // },
                                    data: {
                                        nType: 'route_started',
                                    },
                                    notification:{
                                      title : 'Your bus is arriving',
                                      body : `Trip #${newTrip.id} has started on route ${tracking.routeNames.get(newTrip.route)}`,
                                    },

                                    android: {
                                        notification: {
                                          channel_id: "busbuddy_broadcast",
                                          default_sound: true,
                                        }
                                    },
                                };
                        
                                FCM.sendToMultipleToken (message, notif_list, function(err, response) {
                                    if (err) errLogger.error (err);
                                    else historyLogger.debug (response);
                                });
                            };
                        }).catch(e => {
                            errLogger.error(e.stack);
                            return null;
                        });

                        dbclient.query(
                            `select distinct sess->>'fcm_id' as fcm_id from session 
                             where sess->>'fcm_id' is not null and sess->>'userid' = $1`, 
                             [newTrip.helper]
                        ).then(qres => {
                            if (qres.rows.length > 0) {
                                let token = qres.rows[0].fcm_id;
                                let message = {
                                    token: token,
                                    data: {
                                        nType: 'helper_trip_start',
                                    },
                                    notification: {
                                        title: "Your assigned trip has started.",
                                        body: `Trip #${newTrip.id} has started on route ${tracking.routeNames.get(newTrip.route)} by ${newTrip.driver}.`,
                                    },
                                    android: {
                                        notification: {
                                        channel_id: "busbuddy_broadcast",
                                        default_sound: true,
                                        }
                                    },
                                };
                                FCM.send (message, function(err, response) {
                                    if (err) errLogger.error (err);
                                    else historyLogger.debug (response);
                                });
                            };
                        }).catch(e => {
                            errLogger.error(e.stack);
                        });
                    } else {
                        res.send({
                            success: false,
                        });
                    };
                }).catch(e => errLogger.error(e.stack));
            }).catch(e => errLogger.error(e.stack));
        } else {
            res.send({
                success: false,
            });
        };
    };
});

app.post('/api/endTrip', async (req,res) => {
    if (req.session.userid && req.session.user_type=="bus_staff" && req.session.bus_role=="driver") {
        consoleLogger.info(req.body);
        let t_id = await tracking.busStaffMap.get(req.session.userid);
        let trip = await tracking.runningTrips.get(t_id);
        if (trip) {
            let timeWindowStr = "{";
            for (let i=0; i<trip.time_window.length; i++) {
                timeWindowStr += `"${trip.time_window[i].toISOString()}"`;
                if (i<trip.time_window.length-1) timeWindowStr += ", ";
            };
            timeWindowStr += "}";
            let pathStr = "{";
            for (let i=0; i<trip.path.length; i++) {
                pathStr += `"(${trip.path[i].latitude}, ${trip.path[i].longitude})"`;
                if (i<trip.path.length-1) pathStr += ", ";
            };
            pathStr += "}";
            historyLogger.debug(pathStr);
            let timeListStr = "{";
            for (let i=0; i<trip.time_list.length; i++) {
                if (trip.time_list[i].time) 
                    timeListStr += `"(${trip.time_list[i].station}, \\\"${trip.time_list[i].time.toISOString()}\\\")"`;
                else timeListStr += "null";
                if (i<trip.time_list.length-1) timeListStr += ",";
            };
            timeListStr += "}";
            let lt = await trip.start_location.latitude;
            let lg = await trip.start_location.longitude;
            dbclient.query(
                `update trip set end_timestamp=current_timestamp, passenger_count=$1, start_location=$2, end_location=$3, 
                is_live=false, path=$6, time_list=$7, time_window=$8 where id=$4 and (driver=$5 or helper=$5)`, 
                [trip.passenger_count, ('('+lt+','+lg+')'),  
                ('('+req.body.latitude+','+req.body.longitude+')'), 
                t_id, req.session.userid, pathStr, timeListStr, timeWindowStr]
            ).then(qres => {
                historyLogger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => errLogger.error(e.stack));
            tracking.busStaffMap.delete (trip.driver);
            tracking.busStaffMap.delete (trip.helper);
            tracking.runningTrips.delete (t_id);
            dbclient.query(
                `select distinct sess->>'fcm_id' as fcm_id from session 
                 where sess->>'fcm_id' is not null and sess->>'userid' = $1`, 
                 [trip.helper]
            ).then(qres => {
                if (qres.rows.length > 0) {
                    let token = qres.rows[0].fcm_id;
                    let message = {
                        token: token,
                        data: {
                            nType: 'helper_trip_end',
                        },
                        notification: {
                            title: "Your assigned trip has ended.",
                            body: `Trip #${trip.id} on route ${tracking.routeNames.get(trip.route)} has been ended by ${trip.driver}.`,
                        },
                        android: {
                            notification: {
                            channel_id: "busbuddy_broadcast",
                            default_sound: true,
                            }
                        },
                    };
                    FCM.send (message, function(err, response) {
                        if (err) errLogger.error (err);
                        else historyLogger.debug (response);
                    });
                };
            }).catch(e => {
                errLogger.error(e.stack);
            });
        } else {
            dbclient.query(
                `update trip set end_timestamp=current_timestamp, is_live=false where id=$1 and (driver=$2 or helper=$2)`, 
                [t_id, req.session.userid]
            ).then(qres => {
                historyLogger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => errLogger.error(e.stack));
        };
    };
});

// app.post('/api/getCrewMap', (req,res) => {
//     let crewMap = [];
//     tracking.busStaffMap.forEach (async (t_id, s_id) => {
//         crewMap.push({
//             s_id: s_id,
//             t_id: t_id,
//         });
//     });
//     res.send({
//         success: true,
//         data: [...crewMap],
//     });
// });

app.post('/api/updateStaffLocation', (req,res) => {
    
    if (req.session.userid && req.session.user_type=="bus_staff" && req.session.bus_role=="driver") {
        consoleLogger.info(req.body);
        let t_id = tracking.busStaffMap.get(req.session.userid);
        let trip = tracking.runningTrips.get(t_id);
        if (trip) {
            let r_coord = {
                latitude: req.body.latitude, 
                longitude: req.body.longitude
            };
            trip.time_list.forEach( async (tp, i, arr) => {
                let p_coords = tracking.stationCoords.get(tp.station);
                let dist = geolib.getDistance(p_coords, r_coord);
                historyLogger.debug(dist);               
                if (dist <= 180 && tp.time == null) {
                    consoleLogger.info(trip.id + " crossed " + tp.station);
                    tp.time = new Date();
                    if (trip.travel_direction == "to_buet" && i < arr.length-2) {
                        nextStation = arr[i+1].station;
                        consoleLogger.info("coming up next: " + nextStation);
                        let notif_list;  
                        // consoleLogger.info("trying to get list for notif");
                        dbclient.query(
                            `select array(select distinct s.sess->>'fcm_id' from session s, student st 
                            where st.id=sess->>'userid' and s.sess->>'fcm_id' is not null and st.default_station=$1)`, [nextStation]
                        ).then(qres3 => {
                            historyLogger.debug(qres3);
                            notif_list = [...qres3.rows[0].array];
                            if (notif_list) {
                                consoleLogger.info(notif_list);
                                let message = {
                                    data: {
                                        nType: 'station_approaching',
                                    },
                                    notification:{
                                      title : 'Your bus is very close to your stop.',
                                      body  : `Trip #${trip.id} has crossed ${tracking.stationNames.get(tp.station)} and` + 
                                              ` is approaching ${tracking.stationNames.get(nextStation)}`,
                                    },
                                    android: {
                                        notification: {
                                          channel_id: "busbuddy_broadcast",
                                          default_sound: true,
                                        }
                                    },
                                };
                        
                                FCM.sendToMultipleToken (message, notif_list, function(err, response) {
                                    if (err) errLogger.error (err);
                                    else historyLogger.debug (response);
                                });
                            };
                        }).catch(e => {
                            errLogger.error(e.stack);
                            return null;
                        });
                    };
                };
            });
            trip.path.push(r_coord);
            if (trip.time_window.length === 10) trip.time_window.shift();
            trip.time_window.push(new Date());
            res.send({
                success: true,
            });
        } else {
            res.send({
                success: false,
            });
        };
    };
});

app.post('/api/staffScanTicket', (req,res) => {
    if (req.session.userid && req.session.user_type=="bus_staff") {
        consoleLogger.info(req.body);
        let t_id = tracking.busStaffMap.get(req.session.userid);
        if (t_id) {
            let route = tracking.runningTrips.get(t_id).route;
            dbclient.query(
                `with tk as (
                    update ticket set trip_id=$1, is_used=true, scanned_by=$2 
                    where id=$3 and is_used=false returning student_id
                ) select student_id, 
                array(select s.sess->>'fcm_id' from tk, session s where s.sess->>'userid' = tk.student_id) from tk`, 
                [t_id, req.session.userid, req.body.ticket_id]
            ).then(qres => {
                if (qres.rowCount === 1) {
                    let td = tracking.runningTrips.get(t_id);
                    td.passenger_count += 1;
                    historyLogger.debug(qres);
                    res.send({ 
                        success: true,
                        student_id: qres.rows[0].student_id,
                        passenger_count: td.passenger_count.toString(),
                    });
                    
                    let notif_list = qres.rows[0].array;
                    if (notif_list) {
                        consoleLogger.info(notif_list);
                        let message = {
                            data: {
                            nType: 'ticket_used',
                            },
                            notification:{
                            title : 'Ticket scanned successfully',
                            body : `Your was scanned during Trip#${t_id} on Route#${route}`,
                            },
                            android: {
                                notification: {
                                channel_id: "busbuddy_broadcast",
                                default_sound: true,
                                }
                            },
                        };
                        FCM.sendToMultipleToken (message, notif_list, function(err, response) {
                            if (err) errLogger.error (err);
                            else historyLogger.debug (response);
                        });
                    };

                    dbclient.query(
                        `select count(*) from ticket where student_id=$1 and is_used = false`, 
                        [qres.rows[0].student_id,]
                    ).then(qres2 => {
                        historyLogger.debug(qres2);
                        if (qres2.rowCount === 1) { 
                            let count = qres2.rows[0].count;
                            if (count < 10) {
                                let warning = {
                                    data: {
                                    nType: 'ticket_low_warning',
                                    },
                                    notification:{
                                    title : 'WARNING: Tickets running low!',
                                    body : `You have less than 10 tickets remaining. Please buy more tickets to continue using the bus service.`,
                                    },
                                    android: {
                                        notification: {
                                        channel_id: "busbuddy_broadcast",
                                        default_sound: true,
                                        }
                                    },
                                };
                                FCM.sendToMultipleToken (warning, notif_list, function(err, response) {
                                    if (err) errLogger.error (err);
                                    else historyLogger.debug (response);
                                });
                            };
                        };
                    }).catch(e => errLogger.error(e.stack));
                } else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => {
                errLogger.error(e.stack);
                res.send({
                    success: false,
                });
            });
        };
    };
});

app.post('/api/broadcastNotification', (req,res) => {
    consoleLogger.info(req.body);
    dbclient.query(
        `INSERT INTO broadcast_notification (title, body, timestamp) 
         values ($1, $2, current_timestamp)`, 
        [req.body.nTitle, req.body.nBody]
    ).then(qres2 => {
        historyLogger.debug(qres2);
        if (qres2.rowCount === 1) {
            dbclient.query(
                `select array(select distinct sess->>'fcm_id' from session where sess->>'fcm_id' is not null)`, 
            ).then(qres => {
                let tokenList = [...qres.rows[0].array];
                let message = {
                    data: {
                        nType: 'broadcast',
                    },
                    notification: {
                        title: req.body.nTitle,
                        body: req.body.nBody,
                    },
                    android: {
                        notification: {
                          channel_id: "busbuddy_broadcast",
                          default_sound: true,
                        },
                    },
                };
                FCM.sendToMultipleToken (message, tokenList, function(err, response) {
                    if (err) errLogger.error (err);
                    else historyLogger.debug (response);
                });
            }).then(r => {
                res.send({
                    success: true,
                });
            }).catch(e => {
                errLogger.error(e.stack);
                res.send({
                    success: false,
                });
            });
        } else if (qres2.rowCount === 0) {
            res.send({
                success: false,
            });
        };
    }).catch(e => errLogger.error(e.stack));
});


app.post('/api/personalNotification', (req,res) => {
    consoleLogger.info(req.body);
    dbclient.query(
        `INSERT INTO personal_notification (title, body, user_id, timestamp) 
         values ($1, $2, $3, current_timestamp)`, 
        [req.body.nTitle, req.body.nBody, req.body.user_id]
    ).then(qres2 => {
        historyLogger.debug(qres2);
        if (qres2.rowCount === 1) {
            dbclient.query(
                `select array(select distinct sess->>'fcm_id' from session 
                 where sess->>'fcm_id' is not null and sess->>'userid' = $1)`, 
                 [req.body.user_id]
            ).then(qres => {
                let tokenList = [...qres.rows[0].array];
                let message = {
                    data: {
                        nType: 'personal',
                    },
                    notification: {
                        title: req.body.nTitle,
                        body: req.body.nBody,
                    },
                    android: {
                        notification: {
                          channel_id: "busbuddy_broadcast",
                          default_sound: true,
                        }
                    },
                };
                FCM.sendToMultipleToken (message, tokenList, function(err, response) {
                    if (err) errLogger.error (err);
                    else historyLogger.debug (response);
                });
            }).then(r => {
                res.send({
                    success: true,
                });
            }).catch(e => {
                errLogger.error(e.stack);
                res.send({
                    success: false,
                });
            });
        } else if (qres2.rowCount === 0) {
            res.send({
                success: false,
            });
        };
    }).catch(e => errLogger.error(e.stack));
});


const server = app.listen(port, () => {
    consoleLogger.info(`\n\nBudBuddy backend listening on port ${port}\n\n`);
});

const httpTerminator = createHttpTerminator({ server });

readline.emitKeypressEvents(process.stdin);

if (process.stdin.isTTY) process.stdin.setRawMode(true);

process.stdin.on('keypress', async (chunk, key) => {
    if (key && key.name == 'b') {
        consoleLogger.info("\n\nInitiating Server Shutdown\n");
        await httpTerminator.terminate();
        consoleLogger.info("Connections closed, creating backups");

        let backupCount = tracking.runningTrips.size, backupDone = 0;
        if (backupCount == 0) {
            consoleLogger.info("\nnothing to back up");
            process.exit();
        } else tracking.runningTrips.forEach ((trip) => {
            consoleLogger.info("backing up " + trip.id);
            let timeWindowStr = "{";
            for (let i=0; i<trip.time_window.length; i++) {
                timeWindowStr += `"${trip.time_window[i].toISOString()}"`;
                if (i<trip.time_window.length-1) timeWindowStr += ", ";
            };
            timeWindowStr += "}";
            historyLogger.debug(timeWindowStr);
            let pathStr = "{";
            for (let i=0; i<trip.path.length; i++) {
                pathStr += `"(${trip.path[i].latitude}, ${trip.path[i].longitude})"`;
                if (i<trip.path.length-1) pathStr += ", ";
            };
            pathStr += "}";
            historyLogger.debug(pathStr);
            let timeListStr = "{";
            for (let i=0; i<trip.time_list.length; i++) {
                if (trip.time_list[i].time) 
                    timeListStr += `"(${trip.time_list[i].station}, \\\"${trip.time_list[i].time.toISOString()}\\\")"`;
                else timeListStr += `"(${trip.time_list[i].station}, \\\"${(new Date(0)).toISOString()}\\\")"`;
                if (i<trip.time_list.length-1) timeListStr += ",";
            };
            timeListStr += "}";
            dbclient.query(
                `update trip set passenger_count=$1, path=$2, time_list=$3, time_window=$5 where id=$4`, 
                [trip.passenger_count, pathStr, timeListStr, trip.id, timeWindowStr]
            ).then(qres => {
                historyLogger.debug(qres);
                consoleLogger.info("backed up " + trip.id);
                tracking.runningTrips.delete(trip.id);
                backupDone++;
                if (backupCount == backupDone) {
                    consoleLogger.info ("\nbackups completed");
                    consoleLogger.info("\nbye");
                    process.exit();
                };
            }).catch(e => errLogger.error(e.stack));
        });

        // while (backupDone < backupCount);
    };
    if (key && key.name == 'n') {

        var token = 'dVj_grVZT82cpXtN9RZUEr:APA91bHjgnFIoOTDcMO4h6Ma7dXNbBQMVbEkMnjy_8rBhPyfTJQwmxASrat1UPDyc5zLoaRIOR57gMVZH9G5LyeuIjcGBmMgkNE-rCsDni_vkPh1i-0xlwzaiYeoVz3L9KxuCrluaiuV';
        var message = {
            // data: {    //This is only optional, you can send any data
            //     title : 'Title of notification',
            //     body : 'Body of notification'
            // },
            notification:{
                title : 'Title of notification',
                body : 'Body of notification'
            },
            android: {
                notification: {
                  channel_id: "busbuddy_broadcast",
                  default_sound: true,
                }
            },
            token : token
        };

        FCM.send(message, function(err, response) {
            if (err) errLogger.error (err);
            else historyLogger.debug (response);
        });
    };
    if (key && key.name == 'x') process.exit();
});