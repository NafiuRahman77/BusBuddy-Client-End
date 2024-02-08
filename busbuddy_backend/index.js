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
const fs = require("fs");
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
const serviceAccount = require("busbuddy-user-end-firebase-adminsdk.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const certPath = admin.credential.cert(serviceAccount);
const fcm = require("fcm-notification");
const FCM = new fcm (certPath);

const log4js = require("log4js");
log4js.configure({
    appenders: { busbuddy: { type: "file", filename: "busbuddy.log", maxLogSize: 100000000 } },
    categories: { default: { appenders: ["busbuddy"], level: "debug" } },
});
const logger = log4js.getLogger("busbuddy");
const readline = require('readline');

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


const getRealISODate = () => {
    return (new Date(Date.now() - (new Date()).getTimezoneOffset() * 60000)).toISOString().substring(0, 10);
};


var token = 'dVj_grVZT82cpXtN9RZUEr:APA91bHjgnFIoOTDcMO4h6Ma7dXNbBQMVbEkMnjy_8rBhPyfTJQwmxASrat1UPDyc5zLoaRIOR57gMVZH9G5LyeuIjcGBmMgkNE-rCsDni_vkPh1i-0xlwzaiYeoVz3L9KxuCrluaiuV';
 
    var message = {
        data: {    //This is only optional, you can send any data
            score: '850',
            time: '2:45'
        },
        notification:{
            title : 'Title of notification',
            body : 'Body of notification'
        },
        token : token
        };
 
FCM.send(message, function(err, response) {
    if(err){
        console.log('error found', err);
    }else {
        console.log('response here', response);
    }
})

dbclient.query(
    `select *, array_to_json(time_list) as list_time from trip where is_live=true`
).then(qres2 => {
    //console.log(qres2.rows[0].start_location);
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
        td.list_time.forEach (async tp =>  {
            // newTrip.time_list.push({...tp});
            newTrip.time_list.push({
                station: tp.station,
                time: (tp.time == "1970-01-01T06:00:00+06:00")? null : new Date(tp.time),
            });
        });
        if (td.path) td.path.forEach (async p =>  {
            // newTrip.time_list.push({...tp});
            newTrip.path.push({
                latitude: p.x.toString(),
                longitude: p.y.toString(),
            });
        });
        newTrip.passenger_count = td.passenger_count;
        tracking.runningTrips.set (newTrip.id, newTrip);
        tracking.busStaffMap.set (newTrip.driver, newTrip.id);
        tracking.busStaffMap.set (newTrip.helper, newTrip.id);
    });
}).catch(e => console.error(e.stack));

dbclient.query("SELECT id, coords FROM station").then(qres => {
    // console.log(qres.rows);
    qres.rows.forEach( (st)  =>  {
        tracking.stationCoords.set(st.id, {
            latitude: st.coords.x,
            longitude: st.coords.y,
        });
    });
    // console.log(tracking.stationCoords);
}).catch(e => console.error(e.stack));

app.post('/api/login', (req, res) => {
    // console.log(req.body);
    dbclient.query(
        `SELECT name, password FROM student WHERE id=$1`, [req.body.id]
    ).then (async qres => {
        // console.log(qres);
        if (qres.rows.length === 0) {
            dbclient.query(
                `SELECT name, password FROM buet_staff WHERE id=$1`, [req.body.id]
            ).then (async qres2 => {
                // console.log(qres);
                if (qres2.rows.length === 0) {
                    dbclient.query(
                        `SELECT name, password FROM bus_staff WHERE id=$1`, [req.body.id]
                    ).then (async qres3 => {
                        logger.debug(qres3);
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
                                    logger.debug(qres4);
                                    let relogin = false;
                                    if (qres4.rows.length > 0) {
                                        req.sessionStore.destroy(qres4.rows[0].sid);
                                        relogin = true;
                                    };
                                    req.session.userid = req.body.id;
                                    req.session.user_type = "bus_staff";
                                    res.send({
                                        success: true,
                                        name: qres3.rows[0].name,
                                        user_type: "bus_staff",
                                        relogin: relogin,
                                    });
                                    console.log(req.session);
                                }).catch(e => console.error(e.stack));
                            } else {
                                res.send({ 
                                    success: false,
                                    name: null,
                                    relogin: false
                                });
                            };
                        };
                    }).catch(e => console.error(e.stack));
                } else {
                    let verif = await bcrypt.compare (req.body.password, qres2.rows[0].password);
                    if (verif === true) {
                        req.session.userid = req.body.id;
                        req.session.user_type = "buet_staff";
                        res.send({
                            success: true,
                            name: qres2.rows[0].name,
                            user_type: "buet_staff"
                        });
                        console.log(req.session);
                    } else {
                        res.send({ 
                            success: false,
                            name: null,
                            relogin: false
                        });
                    };
                };
            }).catch(e => console.error(e.stack));
        } else {
            let verif = await bcrypt.compare (req.body.password, qres.rows[0].password);
            if (verif === true) {
                req.session.userid = req.body.id;
                req.session.user_type = "student";
                res.send({
                    success: true,
                    name: qres.rows[0].name,
                    user_type: "student"
                });
                console.log(req.session);
            } else {
                res.send({ 
                    success: false,
                    name: null,
                    relogin: false
                });
            };
        };
    }).catch(e => console.error(e.stack));
});

app.post('/api/sessionCheck', (req, res) => {
    if (req.session.userid) {
        res.send({
            recognized: true,
            relogin: false,
            user_type: req.session.user_type,
            user_id: req.session.userid,
        });
    } else {
        res.send({
            recognized: false,
            relogin: false,
        });
    };
});

// app.post('/api/adminLogin', (req, res) => {
//     console.log(req.body);
//     dbclient.query(
//         `SELECT name FROM admin WHERE id=$1 AND password=$2`,
//         [req.body.id, req.body.password]
//     ).then(qres => {
//         //console.log(qres);
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
//             console.log(req.session);
//         };
//     }).catch(e => console.error(e.stack));
// });

app.post('/api/logout',(req,res) => {
    req.session.destroy();
    res.send({
        success: true
    });
});

app.post('/api/getProfile', (req, res) => {
    logger.debug(req.session);
    if (req.session.userid) {
        if (req.session.user_type == "student") {
            dbclient.query(
                `select s.id as id, s.name as name, phone, email, default_route, r.terminal_point as default_route_name, default_station, st.name as default_station_name
                from student as s, route as r, station as st where s.id=$1 and s.default_route=r.id and s.default_station=st.id`, 
                [req.session.userid]
            ).then(qres => {
                //console.log(qres);
                if (qres.rows.length === 0) res.send({ 
                    success: false,
                });
                else {
                    res.send({
                        ...qres.rows[0],
                        success: true,
                    });
                };
            }).catch(e => console.error(e.stack));
        } else if (req.session.user_type == "buet_staff") {
            dbclient.query(
                `select id, name, phone, department, designation, residence from buet_staff where id=$1`,
                [req.session.userid]
            ).then(qres => {
                //console.log(qres);
                if (qres.rows.length === 0) res.send({ 
                    success: false,
                });
                else {
                    res.send({
                        ...qres.rows[0],
                        success: true,
                    });
                };
            }).catch(e => console.error(e.stack));
        } else if (req.session.user_type == "bus_staff") {
            dbclient.query(
                `select id, name, phone, role from bus_staff where id=$1`,
                [req.session.userid]
            ).then(qres => {
                //console.log(qres);
                if (qres.rows.length === 0) res.send({ 
                    success: false,
                });
                else {
                    res.send({
                        ...qres.rows[0],
                        success: true,
                    });
                };
            }).catch(e => console.error(e.stack));
        };
    };
});

app.post('/api/getProfileStatic', (req, res) => {
    // console.log(req);
    if (req.session.userid) {
        if (req.session.user_type == "student" || req.session.user_type == "buet_staff" || req.session.user_type == "bus_staff") {
            dbclient.query(
                `select id, name from ${dbclient.escapeIdentifier(req.session.user_type)} where id=$1`, 
                [req.session.userid]
            ).then(qres => {
                logger.debug(qres);
                if (qres.rows.length === 0) res.send({ 
                    success: false,
                });
                else {
                    let response;
                    if (fs.existsSync("../../busbuddy_storage/"+req.session.userid))
                        response = new Buffer(fs.readFileSync("../../busbuddy_storage/"+req.session.userid)).toString('base64');
                    else response = "";
                    res.send({
                        ...qres.rows[0],
                        success: true,
                        imageStr: response,
                    });
                };
            }).catch(e => console.error(e.stack));
        } else console.log("Session not recognised.")
    };
});

app.post('/api/updatePassword', (req, res) => {
    // console.log(req);
    if (req.session.userid) {
        if (req.session.user_type == "student" || req.session.user_type == "buet_staff" || req.session.user_type == "bus_staff") {
            dbclient.query(
                `select id, password from ${dbclient.escapeIdentifier(req.session.user_type)} where id=$1`, 
                [req.session.userid]
            ).then (async qres => {
                logger.debug(qres);
                if (qres.rows.length === 0) {
                    res.send({ 
                        success: false,
                    });
                } else {
                    let verif = await bcrypt.compare (req.body.old, qres.rows[0].password);
                    if (verif === true) {
                        let newHash = await bcrypt.hash (req.body.new, bcryptSaltRounds);
                        dbclient.query(
                            `update ${dbclient.escapeIdentifier(req.session.user_type)} set password=$1 where id=$2 and password=$3`, 
                            [newHash, req.session.userid, qres.rows[0].password]
                        ).then (async qres2 => {
                            logger.debug(qres2);
                            if (qres2.rowCount === 1) {
                                res.send({ 
                                    success: true,
                                });
                            } else {
                                res.send({ 
                                    success: false,
                                });
                            };
                        }).catch(e => console.error(e.stack));
                    } else {
                        res.send({ 
                            success: false,
                        });
                    };
                };
            }).catch(e => console.error(e.stack));
        } else console.log("Session not recognised.")
    };
});

app.post('/api/getDefaultRoute', (req, res) => {
    logger.debug(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select default_route, r.terminal_point as default_route_name 
            from student as s, route as r where s.id=$1 and s.default_route=r.id`, 
            [req.session.userid]
        ).then(qres => {
            //console.log(qres);
            if (qres.rows.length === 0) res.send({ 
                success: false,
            });
            else {
                res.send({
                    ...qres.rows[0],
                    success: true,
                });
            };
        }).catch(e => console.error(e.stack));
    };
});     

app.post('/api/updateProfile', (req,res) => {
    logger.debug(req.body);
    if (req.session.userid === req.body.id) {
        if (req.session.user_type == "student") {
            dbclient.query(
                `UPDATE student SET phone=$1, email=$2, default_route=$3, default_station=$4 WHERE id=$5`, 
                [req.body.phone, req.body.email, req.body.default_route, req.body.default_station, req.body.id]
            ).then(qres => {
                logger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => console.error(e.stack));
        } else if (req.session.user_type == "buet_staff") {
            dbclient.query(
                `UPDATE buet_staff SET phone=$1, residence=$2 WHERE id=$3`, 
                [req.body.phone, req.body.residence, req.body.id]
            ).then(qres => {
                logger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => console.error(e.stack));
        } else if (req.session.user_type == "bus_staff") {
            dbclient.query(
                `UPDATE bus_staff SET phone=$1 WHERE id=$2`, 
                [req.body.phone, req.body.id]
            ).then(qres => {
                logger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => console.error(e.stack));
        } 
    };
});

app.post('/api/getRoutes', (req,res) => {
    console.log("sending route data");
    dbclient.query("SELECT id, terminal_point FROM route").then(qres => {
        res.send(qres.rows);
    }).catch(e => console.error(e.stack));
});

app.post('/api/getStations', (req,res) => {
    console.log("sending station data");
    dbclient.query("SELECT id, name, coords FROM station").then(qres => {
        res.send(qres.rows);
    }).catch(e => console.error(e.stack));
});

app.post('/api/getRouteStations', (req,res) => {
    console.log("sending route station data");
    dbclient.query("SELECT id, name FROM station where id in (select unnest(points) from route where id = $1)",
		   [ req.body.route]).then(qres => {
        res.send(qres.rows);
    }).catch(e => console.error(e.stack));
});

app.post('/api/addFeedback', (req,res) => {
    logger.debug(req.body);
    if (req.session.userid) {
        if (req.session.user_type == "student") {
            dbclient.query(
                `INSERT INTO student_feedback (complainer_id, route, submission_timestamp, concerned_timestamp, text, subject) 
                values ($1, $2, NOW(), $3, $4, $5)`, 
                [req.session.userid, req.body.route==""? null:req.body.route, 
                req.body.timestamp==""? null:req.body.timestamp, req.body.text, JSON.parse(req.body.subject)]
            ).then(qres => {
                logger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => console.error(e.stack));
        } else if (req.session.user_type == "buet_staff") {
            dbclient.query(
                `INSERT INTO buet_staff_feedback (complainer_id, route, submission_timestamp, concerned_timestamp, text, subject) 
                values ($1, $2, NOW(), $3, $4, $5)`, 
                [req.session.userid, req.body.route==""? null:req.body.route, 
                req.body.timestamp==""? null:req.body.timestamp, req.body.text, JSON.parse(req.body.subject)]
            ).then(qres => {
                logger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => console.error(e.stack));
        }
        
    };
});

app.post('/api/addRequisition', (req,res) => {
    console.log(req.body);
    if (req.session.userid) {
        dbclient.query(
            `INSERT INTO requisition (requestor_id, destination, bus_type, subject, text, timestamp) 
            values ($1, $2, $3, $4, $5, $6)`, 
            [req.session.userid, req.body.destination, JSON.parse(req.body.bus_type), req.body.subject, req.body.text, req.body.timestamp]
        ).then(qres => {
            logger.debug(qres);
            if (qres.rowCount === 1) res.send({ 
                success: true,
            });
            else if (qres.rowCount === 0) {
                res.send({
                    success: false,
                });
            };
        }).catch(e => console.error(e.stack));
    };
});

app.post('/api/purchaseTickets', (req,res) => {
    if (req.session.userid) {
        dbclient.query(
            `CALL make_purchase($1, $2, $3, $4)`, 
            [req.session.userid, req.body.method, req.body.trxid, req.body.count]
        ).then(qres => {
            logger.debug(qres);
            dbclient.query(
                `select * from purchase where trxid=$1`, 
                [req.body.trxid]
            ).then(qres => {
                logger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => console.error(e.stack));
        }).catch(e => console.error(e.stack));
    };
});

app.post('/api/getTicketCount', (req,res) => {
    // console.log(req.body);
    if (req.session.userid) {
        dbclient.query(
            `select count(*) from ticket where student_id=$1 and is_used = false`, 
            [req.session.userid]
        ).then(qres => {
            logger.debug(qres);
            if (qres.rowCount === 1) res.send({ 
                success: true,
                count: qres.rows[0].count,
            });
            else if (qres.rowCount === 0) {
                res.send({
                    success: false,
                });
            };
        }).catch(e => console.error(e.stack));
    };
});

app.post('/api/getTicketQRData', (req,res) => {
    console.log(req.body);
    if (req.session.userid && req.session.user_type=="student") {
        dbclient.query(
            `select id from ticket where student_id=$1 and is_used=false limit 1`, 
            [req.session.userid]
        ).then(qres => {
            logger.debug(qres);
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
        }).catch(e => console.error(e.stack));
    };
});

app.post('/api/getTicketList', (req,res) => {
    console.log(req.body);
    if (req.session.userid && req.session.user_type=="student") {
        dbclient.query(
            `select id from ticket where student_id=$1 and is_used=false order by student_id limit 5`, 
            [req.session.userid]
        ).then(qres => {
            logger.debug(qres);
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
        }).catch(e => console.error(e.stack));
    };
});

app.post('/api/getUserFeedback', (req, res) => {
    logger.debug(req.session);
    if (req.session.userid) {
        if (req.session.user_type == "student") {
            dbclient.query(
            `select f.*, r.terminal_point as route_name
            from student_feedback as f, public.route as r 
            where f.route = r.id and f.complainer_id = $1`, [req.session.userid]
            ).then(qres => {
                logger.debug(qres);
                res.send(qres.rows);
            }).catch(e => {
                console.error(e.stack);
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
                logger.debug(qres);
                res.send(qres.rows);
            }).catch(e => {
                console.error(e.stack);
                res.send({ 
                    success: false,
                });
            });
        } 
    };
});

app.post('/api/getUserRequisition', (req, res) => {
    logger.debug(req.session);
    if (req.session.userid) {
        dbclient.query(
           `select * from requisition where requestor_id = $1`, [req.session.userid]
        ).then(qres => {
            logger.debug(qres);
            res.send(qres.rows);
        }).catch(e => {
            console.error(e.stack);
            res.send({ 
                success: false,
            });
        });
    };
});

app.post('/api/getUserPurchaseHistory', (req, res) => {
    logger.debug(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select * from purchase where buyer_id=$1`, [req.session.userid]
        ).then(qres => {
            //log(qres);
            res.send(qres.rows);
        }).catch(e => {
            console.error(e.stack);
            res.send({ 
                success: false,
            });
        });
    };
});

app.post('/api/getTicketUsageHistory', (req, res) => {
    logger.debug(req.session);
    if (req.session.userid && req.session.user_type == 'student') {
        dbclient.query(
            `select tk.trip_id, tr.route, tr.start_timestamp, tr.travel_direction, 
            tr.bus, tk.scanned_by from ticket tk, trip tr where tk.is_used = true 
            and tk.trip_id = tr.id and tk.student_id=$1`, [req.session.userid]
        ).then(qres => {
            //log(qres);
            res.send(qres.rows);
        }).catch(e => {
            console.error(e.stack);
            res.send({ 
                success: false,
            });
        });
    };
});


app.post('/api/getRouteTimeData', (req, res) => {
    logger.debug(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select lpad(id::varchar, 8, '0') as id, start_timestamp, route, array_to_json(time_list), bus
             from allocation where route=$1`, [req.body.route]
        ).then(qres => {
	    let list = [...qres.rows];
	    //list.forEach(trip => {
	//	trip.time_list = JSON.parse(trip.timeList);
	  //  });
            logger.debug(list);
            res.send(qres.rows);
        }).catch(e => {
            console.error(e.stack);
            res.send({ 
                success: false,
            });
        });
    };
});

app.post('/api/getTrackingData', async (req, res) => {
    logger.debug(req.session);
    if (req.session.userid) {
	    let list = [];
        //iterating over map
        tracking.runningTrips.forEach( async trip => {
            if (trip.route == req.body.route) list.push (trip);
        });
        logger.debug(list);
        res.send(list);
    };
});

// app.post('/api/sendRepairRequest', (req,res) => {
//     //send a dummy response
//     console.log(req.body);
//     res.send({
//         success: true,
//     });
// });

// app.post('/api/getRepairRequest', (req,res) => {
//     //send a dummy response
//     console.log(req.body);
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
// app.post('/api/getNotifications', (req,res) => {
//     //send a dummy response
//     console.log(req.body);
//     res.send({
//         success: true,
//         data: [
//             {
//                 id: 1,
//                 user_id: "1905067",
//                 heading: "Your bus is near",
//                 body: "Your bus is coming to your location. Please be ready at the bus stop.",
//                 timestamp: "2021-05-01 12:00:00"
//             },
            
           
//         ]
//     });
// });
// //send real time notification api
// app.post('/api/sendNotification', (req,res) => {
//     //send a dummy response
//     console.log(req.body);
//     res.send({
//         success: true,
//     });
// });

// // Teacher bill payment api
// app.post('/api/payBill', (req,res) => {
//     //send a dummy response
//     console.log(req.body);
//     res.send({
//         success: true,
//         payment_id: 1984983210
//     });
// });

// // Teacher bill history api
// app.post('/api/getBillHistory', (req,res) => {
//     //send a dummy response
//     console.log(req.body);
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
    //send a dummy response
    console.log(req.body);
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
//     //send a dummy response
//     console.log(req.body);
//     res.send([
//     {"id":"00000451","start_timestamp":"2023-09-11T00:40:00.000Z","route":"3","array_to_json":[{"station":"17","time":"2023-09-11T06:40:00+06:00"},{"station":"18","time":"2023-09-11T06:42:00+06:00"},{"station":"19","time":"2023-09-11T06:44:00+06:00"},{"station":"20","time":"2023-09-11T06:46:00+06:00"},{"station":"21","time":"2023-09-11T06:48:00+06:00"},{"station":"22","time":"2023-09-11T06:50:00+06:00"},{"station":"23","time":"2023-09-11T06:52:00+06:00"},{"station":"24","time":"2023-09-11T06:54:00+06:00"},{"station":"25","time":"2023-09-11T06:57:00+06:00"},{"station":"26","time":"2023-09-11T07:00:00+06:00"},{"station":"70","time":"2023-09-11T07:15:00+06:00"}],"bus":"Ba-24-8518"},
//     {"id":"00000452","start_timestamp":"2023-09-11T07:40:00.000Z","route":"3","array_to_json":[{"station":"70","time":"2023-09-11T13:40:00+06:00"},{"station":"26","time":"2023-09-11T13:55:00+06:00"},{"station":"25","time":"2023-09-11T13:58:00+06:00"},{"station":"24","time":"2023-09-11T14:00:00+06:00"},{"station":"23","time":"2023-09-11T14:02:00+06:00"},{"station":"22","time":"2023-09-11T14:04:00+06:00"},{"station":"21","time":"2023-09-11T14:06:00+06:00"},{"station":"20","time":"2023-09-11T14:08:00+06:00"},{"station":"19","time":"2023-09-11T14:10:00+06:00"},{"station":"18","time":"2023-09-11T14:12:00+06:00"},{"station":"17","time":"2023-09-11T14:14:00+06:00"}],"bus":"Ba-24-8518"},]);
// });

//get trip data
app.post('/api/getTripData', (req,res) => {
    console.log(req.body);
    res.send({
        success: true,
        ...tracking.runningTrips.get(req.body.trip_id),
    });
});

app.post('/api/checkStaffRunningTrip', async (req,res) => {
    // console.log(req.body);
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
    //send a dummy response
    if (req.session.userid && req.session.user_type=="bus_staff") {
        console.log(req.body);
        dbclient.query(
            `select * from allocation where is_done=false and (driver=$1 or helper=$1) order by start_timestamp asc`, 
            [req.session.userid]
        ).then(qres => {
            logger.debug(qres);
            dbclient.query(
                `select * from trip where (driver=$1 or helper=$1) order by start_timestamp desc`, 
                [req.session.userid]
            ).then(qres2 => {
                logger.debug(qres2);
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
            }).catch(e => console.error(e.stack));
        }).catch(e => console.error(e.stack));
    };
});

app.post('/api/startTrip', (req,res) => {
    console.log(req.body);
    if (req.session.userid && req.session.user_type=="bus_staff") {
        let ronin = tracking.busStaffMap.has(req.session.userid);
        if (!ronin) {
            dbclient.query(
                `call initiate_trip2($1, $2, $3)`, 
                [req.body.trip_id, req.session.userid, ('('+req.body.latitude+','+req.body.longitude+')')]
            ).then(qres => {
                // logger.debug(qres);
                dbclient.query(
                    `select *, array_to_json(time_list) as list_time from trip where id=$1`, 
                    [req.body.trip_id]
                ).then(qres2 => {
                    // logger.debug(qres2);
                    if (qres2.rows.length == 1) {
                        let td = {...qres2.rows[0]};
                        logger.debug(td.list_time);
                        let newTrip = new tracking.RunningTrip 
                        (td.id, td.start_timestamp, td.route, td.time_type, 
                            td.travel_direction, td.bus, td.is_default,
                            td.driver, td.helper, td.approved_by, td.end_timestamp,
                            {   
                                latitude: req.body.latitude, 
                                longitude: req.body.longitude
                            }, 
                            td.end_location);
                        td.list_time.forEach (async tp =>  {
                            // newTrip.time_list.push({...tp});
                            newTrip.time_list.push({
                                station: tp.station,
                                time: null
                            });
                        });
                        tracking.runningTrips.set (newTrip.id, newTrip);
                        tracking.busStaffMap.set (newTrip.driver, newTrip.id);
                        tracking.busStaffMap.set (newTrip.helper, newTrip.id);
                        res.send({ 
                            success: true,
                            ...tracking.runningTrips.get(newTrip.id),
                        });
                    } else {
                        res.send({
                            success: false,
                        });
                    };
                }).catch(e => console.error(e.stack));
            }).catch(e => console.error(e.stack));
        } else {
            res.send({
                success: false,
            });
        };
    };
});

app.post('/api/endTrip', async (req,res) => {
    if (req.session.userid && req.session.user_type=="bus_staff") {
        console.log(req.body);
        let t_id = await tracking.busStaffMap.get(req.session.userid);
        let trip = await tracking.runningTrips.get(t_id);
        if (trip) {
            let pathStr = "{";
            for (let i=0; i<trip.path.length; i++) {
                pathStr += `"(${trip.path[i].latitude}, ${trip.path[i].longitude})"`;
                if (i<trip.path.length-1) pathStr += ", ";
            };
            pathStr += "}";
            logger.debug(pathStr);
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
                is_live=false, path=$6, time_list=$7 where id=$4 and (driver=$5 or helper=$5)`, 
                [trip.passenger_count, ('('+lt+','+lg+')'),  
                ('('+req.body.latitude+','+req.body.longitude+')'), 
                t_id, req.session.userid, pathStr, timeListStr]
            ).then(qres => {
                logger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => console.error(e.stack));
            tracking.busStaffMap.delete (trip.driver);
            tracking.busStaffMap.delete (trip.helper);
            tracking.runningTrips.delete (t_id);
        } else {
            dbclient.query(
                `update trip set end_timestamp=current_timestamp, is_live=false where id=$1 and (driver=$2 or helper=$2)`, 
                [t_id, req.session.userid]
            ).then(qres => {
                logger.debug(qres);
                if (qres.rowCount === 1) res.send({ 
                    success: true,
                });
                else if (qres.rowCount === 0) {
                    res.send({
                        success: false,
                    });
                };
            }).catch(e => console.error(e.stack));
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
    //send a dummy response
    if (req.session.userid && req.session.user_type=="bus_staff") {
        console.log(req.body);
        let t_id = tracking.busStaffMap.get(req.session.userid);
        let trip = tracking.runningTrips.get(t_id);
        if (trip) {
            let r_coord = {
                latitude: req.body.latitude, 
                longitude: req.body.longitude
            };
            trip.time_list.forEach( async tp => {
                let p_coords = tracking.stationCoords.get(tp.station);
                let dist = geolib.getDistance(p_coords, r_coord);
                logger.debug(dist);               
                if (dist <= 180) {
                    console.log(trip.route);
                    tp.time = new Date();
                };
            });
            trip.path.push(r_coord);
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
    //send a dummy response
    if (req.session.userid && req.session.user_type=="bus_staff") {
        console.log(req.body);
        let t_id = tracking.busStaffMap.get(req.session.userid);
        dbclient.query(
            `update ticket set trip_id=$1, is_used=true, scanned_by=$2 where id=$3 and is_used=false returning student_id`, 
            [t_id, req.session.user_id, req.body.ticket_id]
        ).then(qres => {
            if (qres.rowCount === 1) {
                let td = tracking.runningTrips.get(t_id);
                td.passenger_count += 1;
                logger.debug(qres);
                res.send({ 
                    success: true,
                    student_id: qres.rows[0].student_id,
                    passenger_count: td.passenger_count.toString(),
                });
            } else if (qres.rowCount === 0) {
                res.send({
                    success: false,
                });
            };
        }).catch(e => {
            console.error(e.stack);
            res.send({
                success: false,
            });
        });
    };
});

const server = app.listen(port, () => {
    console.log(`BudBuddy backend listening on port ${port}`);
});

const httpTerminator = createHttpTerminator({ server });

readline.emitKeypressEvents(process.stdin);

if (process.stdin.isTTY) process.stdin.setRawMode(true);

process.stdin.on('keypress', async (chunk, key) => {
    if (key && key.name == 'b') {
        console.log("\n\nInitiating Server Shutdown\n");
        await httpTerminator.terminate();
        console.log("Connections closed, creating backups");

        let backupCount = tracking.runningTrips.size, backupDone = 0;
        if (backupCount == 0) {
            console.log("\nnothing to back up");
            process.exit();
        } else tracking.runningTrips.forEach ((trip) => {
            console.log("backing up " + trip.id);
            let pathStr = "{";
            for (let i=0; i<trip.path.length; i++) {
                pathStr += `"(${trip.path[i].latitude}, ${trip.path[i].longitude})"`;
                if (i<trip.path.length-1) pathStr += ", ";
            };
            pathStr += "}";
            logger.debug(pathStr);
            let timeListStr = "{";
            for (let i=0; i<trip.time_list.length; i++) {
                if (trip.time_list[i].time) 
                    timeListStr += `"(${trip.time_list[i].station}, \\\"${trip.time_list[i].time.toISOString()}\\\")"`;
                else timeListStr += `"(${trip.time_list[i].station}, \\\"${(new Date(0)).toISOString()}\\\")"`;
                if (i<trip.time_list.length-1) timeListStr += ",";
            };
            timeListStr += "}";
            dbclient.query(
                `update trip set passenger_count=$1, path=$2, time_list=$3 where id=$4`, 
                [trip.passenger_count, pathStr, timeListStr, trip.id]
            ).then(qres => {
                logger.debug(qres);
                console.log("backed up " + trip.id);
                tracking.runningTrips.delete(trip.id);
                backupDone++;
                if (backupCount == backupDone) {
                    console.log ("\nbackups completed");
                    console.log("\nbye");
                    process.exit();
                };
            }).catch(e => console.error(e.stack));
        });

        // while (backupDone < backupCount);
    };
    if (key && key.name == 'x') process.exit();
});