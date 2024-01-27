const express = require('express');
const session = require('express-session');
const path = require('path');
// const cors = require('cors');
const app = express();
const port = 6969;
const bodyParser = require('body-parser');
const cookieParser = require('cookie-parser');
const otpGenerator = require('otp-generator');
const axios = require('axios');
const crypto = require('crypto');
const dotenv = require('dotenv');
const url = require('url')
const { v4: uuidv4 } = require('uuid');
// const pdf = require("pdf-creator-node");
const fs = require("fs");
const multer = require('multer');
// const html = fs.readFileSync("src/ticket.html", "utf8");
const { Readable } = require('stream');
const imageToBase64 = require('image-to-base64');
const tracking = require('./tracking.js');
const pd = require('./path_dump.js');
trip_t = pd.trip_t;

dotenv.config();

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

const getSHA512 = (input) => {
    return crypto.createHash('sha512').update(JSON.stringify(input)).digest('hex');
};


app.use(session({
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: true,
    sameSite: 'none',
    cookie: {
        maxAge: 30*60*1000,
        httpOnly: false
    }
}));


const { Pool, Client } = require('pg');

const dbclient = new Client({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASS,
  port: process.env.DB_PORT,
});

dbclient.connect();

const getRealISODate = () => {
    return (new Date(Date.now() - (new Date()).getTimezoneOffset() * 60000)).toISOString().substring(0, 10);
};

// const initiate_today = () => {
//     dbclient.query("CALL initiate_occupancy_today()").then(res1 => {
//         console.log(res1);
//         dbclient.query("CALL initiate_availability_today()").then(res2 => {
//             console.log(res2);
//         });
//     });
// };

// initiate_today();

// const cron = setInterval (initiate_today, 1800000);

app.post('/api/getSession',(req,res) => {
    if (req.session.userid) {
        dbclient.query(
            `SELECT name FROM customer WHERE mobile=$1`,
            [req.session.userid]
        ).then(qres => {
            res.send({
                success: true,
                name: qres.rows[0].name,
                admin: false
            });
        }).catch(e => {
            req.session.destroy();
            res.send({
                success: false,
            });
            console.error(e.stack)
        });
    }
    else if ( req.session.adminid){
        dbclient.query(
            `SELECT name FROM admin WHERE id=$1`,
            [req.session.adminid]
        ).then(qres => {
            res.send({
                success: true,
                name: qres.rows[0].name,
                admin: true
            });
        }).catch(e => {
            req.session.destroy();
            res.send({
                success: false,
            });
            console.error(e.stack)
        });
    } else {
        res.send({
            success: false,
        });
    }
});

app.post('/api/login', (req, res) => {
    console.log(req.body);

    dbclient.query(
        `SELECT name FROM student WHERE id=$1 AND password=$2`,
        [req.body.id, req.body.password]
    ).then(qres => {
        console.log(qres);
        if (qres.rows.length === 0) {
            dbclient.query(
                `SELECT name FROM buet_staff WHERE id=$1 AND password=$2`,
                [req.body.id, req.body.password]
            ).then(qres => {
                console.log(qres);
                if (qres.rows.length === 0) {
                    dbclient.query(
                        `SELECT name FROM bus_staff WHERE id=$1 AND password=$2`,
                        [req.body.id, req.body.password]
                    ).then(qres => {
                        console.log(qres);
                        if (qres.rows.length === 0) {
                            res.send({ 
                                success: false,
                                name: null
                            });
                        } else {
                            req.session.userid = req.body.id;
                            req.session.user_type = "bus_staff";
                            res.send({
                                success: true,
                                name: qres.rows[0].name,
                                user_type: "bus_staff"
                            });
                            console.log(req.session);
                        };
                    }).catch(e => console.error(e.stack));
                } else {
                    req.session.userid = req.body.id;
                    req.session.user_type = "buet_staff";
                    res.send({
                        success: true,
                        name: qres.rows[0].name,
                        user_type: "buet_staff"
                    });
                    console.log(req.session);
                };
            }).catch(e => console.error(e.stack));
        } else {
            req.session.userid = req.body.id;
            req.session.user_type = "student";
            res.send({
                success: true,
                name: qres.rows[0].name,
                user_type: "student"
            });
            console.log(req.session);
        };
    }).catch(e => console.error(e.stack));
});

app.post('/api/adminLogin', (req, res) => {
    console.log(req.body);

    dbclient.query(
        `SELECT name FROM admin WHERE id=$1 AND password=$2`,
        [req.body.id, req.body.password]
    ).then(qres => {
        //console.log(qres);
        if (qres.rows.length === 0) res.send({ 
            success: false,
            name: null,
        });
        else {
            req.session.adminid = req.body.id;
            res.send({
                success: true,
                name: qres.rows[0].name,
                admin: true
            });
            console.log(req.session);
        };
    }).catch(e => console.error(e.stack));
});


app.post('/api/register', (req, res) => {
    if (req.body.mobile == req.session.userid) {
        console.log(req.body);
        dbclient.query (
            "INSERT INTO customer(mobile, password, nid, dob, name, address) values($1, $2, $3, $4, $5, $6)",
            [req.body.mobile, req.body.password, req.body.nid, req.body.dob, req.body.name, req.body.address]
        ).then(qres => {
            console.log(qres);
            if (qres.rowCount === 1) res.send(true);
            else if (qres.rowCount === 0) res.send(false);
        }).catch(e => {
            console.error(e.stack);
            res.send(false);
        });
    } else res.send(false);
});


app.post('/api/correctUser', (req, res) => {
    if (req.body.mobile == req.session.userid) {
        console.log(req.body);
        dbclient.query (
            "UPDATE customer SET name=$1, dob=$2 WHERE nid=$3",
            [req.body.name, req.body.dob, req.body.nid]
        ).then(qres => {
            console.log(qres);
            if (qres.rowCount === 1) res.send(true);
            else if (qres.rowCount === 0) res.send(false);
        }).catch(e => {
            console.error(e.stack);
            res.send(false);
        });
    } else res.send(false);
});


app.post('/api/logout',(req,res) => {
    req.session.destroy();
    res.send({
        success: true
    });
});

app.post('/api/getProfile', (req, res) => {
    console.log(req.session);
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
        if (req.session.user_type == "student") {
            dbclient.query(
                `select id, name from student where id=$1`, 
                [req.session.userid]
            ).then(qres => {
                console.log(qres);
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
        } else if (req.session.user_type == "buet_staff") {
            dbclient.query(
                `select id, name from buet_staff where id=$1`, 
                [req.session.userid]
            ).then(qres => {
                console.log(qres);
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
        } else if (req.session.user_type == "bus_staff") { 
            dbclient.query(
                `select id, name from bus_staff where id=$1`, 
                [req.session.userid]
            ).then(qres => {
                console.log(qres);
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
        };
    } else console.log("Session not recognised.")
});

app.post('/api/getDefaultRoute', (req, res) => {
    console.log(req.session);

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

// app.post('/api/getSelfID', (req, res) => {
//     console.log(req.session);
//     if (req.session.userid) {
//         dbclient.query(
//             "SELECT nid, name FROM customer WHERE mobile=$1", 
//             [req.session.userid]
//         ).then(qres => {
//             //console.log(qres);
//             if (qres.rows.length === 0) res.send({ 
//                 success: false,
//             });
//             else {
//                 res.send({
//                     ...qres.rows[0],
//                     success: true,
//                 });
//             };
//         }).catch(e => console.error(e.stack));
//     };
// });

app.post('/api/updateProfile', (req,res) => {
    console.log(req.body);
    if (req.session.userid === req.body.id) {
        dbclient.query(
            `UPDATE student SET phone=$1, email=$2, default_route=$3, default_station=$4 WHERE id=$5`, 
            [req.body.phone, req.body.email, req.body.default_route, req.body.default_station, req.body.id]
        ).then(qres => {
            console.log(qres);
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

// app.post('/api/updatePassword', (req,res) => {
//     dbclient.query(
//         `UPDATE customer SET password=$1 WHERE mobile=$2 AND password=$3`, 
//         [req.body.password, req.session.userid, req.body.password0]
//     ).then(qres => {
//         //console.log(qres);
//         if (qres.rowCount === 1) res.send({ 
//             success: true,
//         });
//         else if (qres.rowCount === 0) {
//             res.send({
//                 success: false,
//             });
//         };
//     }).catch(e => console.error(e.stack));
// });

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
    console.log(req.body);
    if (req.session.userid) {
        if (req.session.user_type == "student") {
            dbclient.query(
                `INSERT INTO student_feedback (complainer_id, route, submission_timestamp, concerned_timestamp, text, subject) 
                values ($1, $2, NOW(), $3, $4, $5)`, 
                [req.session.userid, req.body.route==""? null:req.body.route, 
                req.body.timestamp==""? null:req.body.timestamp, req.body.text, JSON.parse(req.body.subject)]
            ).then(qres => {
                console.log(qres);
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
                console.log(qres);
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
            console.log(qres);
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
            console.log(qres);
            dbclient.query(
                `select count(*) from purchase where trxid=$1`, 
                [req.body.trxid]
            ).then(qres => {
                console.log(qres);
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
            `select count(*) from ticket where student_id=$1`, 
            [req.session.userid]
        ).then(qres => {
            console.log(qres);
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
            console.log(qres);
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

app.post('/api/getUserFeedback', (req, res) => {
    console.log(req.session);
    if (req.session.userid) {
        if (req.session.user_type == "student") {
            dbclient.query(
            `select f.*, r.terminal_point as route_name
            from student_feedback as f, public.route as r 
            where f.route = r.id and f.complainer_id = $1`, [req.session.userid]
            ).then(qres => {
                console.log(qres);
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
                console.log(qres);
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
    console.log(req.session);
    if (req.session.userid) {
        dbclient.query(
           `select * from requisition where requestor_id = $1`, [req.session.userid]
        ).then(qres => {
            console.log(qres);
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
    console.log(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select * from purchase where buyer_id=$1`, [req.session.userid]
        ).then(qres => {
            //console.log(qres);
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
    console.log(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select lpad(id::varchar, 8, '0') as id, start_timestamp, route, array_to_json(time_list), bus
             from allocation where route=$1`, [req.body.route]
        ).then(qres => {
	    let list = [...qres.rows];
	    //list.forEach(trip => {
	//	trip.time_list = JSON.parse(trip.timeList);
	  //  });
            console.log(list);
            res.send(qres.rows);
        }).catch(e => {
            console.error(e.stack);
            res.send({ 
                success: false,
            });
        });
    };
});

//dummy

app.post('/api/sendRepairRequest', (req,res) => {
    //send a dummy response
    console.log(req.body);
    res.send({
        success: true,
    });
});

app.post('/api/getRepairRequest', (req,res) => {
    //send a dummy response
    console.log(req.body);
    res.send({
        success: true,
        data: [
            {
                id: 1,
                staff_id: "altaf",
                item : "Engine",
                item_count: "1",
                problem: "Engine problem",
                status: "pending",
                timestamp: "2021-05-01 12:00:00"
            },
            {
                id: 2,
                staff_id: "altaf",
                item : "Engine",
                item_count: "1",
                problem: "Engine problem",
                status: "pending",
                timestamp: "2021-05-01 12:00:00"
            },
            {
                id: 3,
                staff_id: "altaf",
                item : "Engine",
                item_count: "1",
                problem: "Engine problem",
                status: "pending",
                timestamp: "2021-05-01 12:00:00"
            },
            {
                id: 4,
                staff_id: "altaf",
                item : "Engine",
                item_count: "1",
                problem: "Engine problem",
                status: "pending",
                timestamp: "2021-05-01 12:00:00"
            },
           
        ]
    });
}
);

app.post('/api/getNotifications', (req,res) => {
    //send a dummy response
    console.log(req.body);
    res.send({
        success: true,
        data: [
            {
                id: 1,
                user_id: "1905067",
                heading: "Your bus is near",
                body: "Your bus is coming to your location. Please be ready at the bus stop.",
                timestamp: "2021-05-01 12:00:00"
            },
            
           
        ]
    });
});

//send real time notification api
app.post('/api/sendNotification', (req,res) => {
    //send a dummy response
    console.log(req.body);
    res.send({
        success: true,
    });
});

// Teacher bill payment api
app.post('/api/payBill', (req,res) => {
    //send a dummy response
    console.log(req.body);
    res.send({
        success: true,
        payment_id: 1984983210
    });
});

// Teacher bill history api
app.post('/api/getBillHistory', (req,res) => {
    //send a dummy response
    console.log(req.body);
    res.send({
        success: true,
        data: [
            {
                id: 1,
                teacher_id: "mtzcse",
                name: "Md. Toufikuzzaman",
                bill_type: "Monthly",
                bill_amount: "200",
                bill_month: "January",
                bill_year: "2024",
                timestamp: "2021-05-01 12:00:00"
            },       
           
        ]
    });
});

//get route details

//get nearest station
app.post('/api/getNearestStation', (req,res) => {
    //send a dummy response
    console.log(req.body);
    res.send({
        success: true,
        data: [
            {
                station_id: 1,
                station_name: "Mohammadpur",
                station_coordinates: "23.765, 90.365",
                adjacent_stations : "Mirpur, Dhanmondi",
                adjacent_stations_id: "2,3",
            },       
           
        ]
    });
});

app.post('/api/getRouteFromStation', (req,res) => {
    //send a dummy response
    console.log(req.body);
    res.send([
    {"id":"00000451","start_timestamp":"2023-09-11T00:40:00.000Z","route":"3","array_to_json":[{"station":"17","time":"2023-09-11T06:40:00+06:00"},{"station":"18","time":"2023-09-11T06:42:00+06:00"},{"station":"19","time":"2023-09-11T06:44:00+06:00"},{"station":"20","time":"2023-09-11T06:46:00+06:00"},{"station":"21","time":"2023-09-11T06:48:00+06:00"},{"station":"22","time":"2023-09-11T06:50:00+06:00"},{"station":"23","time":"2023-09-11T06:52:00+06:00"},{"station":"24","time":"2023-09-11T06:54:00+06:00"},{"station":"25","time":"2023-09-11T06:57:00+06:00"},{"station":"26","time":"2023-09-11T07:00:00+06:00"},{"station":"70","time":"2023-09-11T07:15:00+06:00"}],"bus":"Ba-24-8518"},
    {"id":"00000452","start_timestamp":"2023-09-11T07:40:00.000Z","route":"3","array_to_json":[{"station":"70","time":"2023-09-11T13:40:00+06:00"},{"station":"26","time":"2023-09-11T13:55:00+06:00"},{"station":"25","time":"2023-09-11T13:58:00+06:00"},{"station":"24","time":"2023-09-11T14:00:00+06:00"},{"station":"23","time":"2023-09-11T14:02:00+06:00"},{"station":"22","time":"2023-09-11T14:04:00+06:00"},{"station":"21","time":"2023-09-11T14:06:00+06:00"},{"station":"20","time":"2023-09-11T14:08:00+06:00"},{"station":"19","time":"2023-09-11T14:10:00+06:00"},{"station":"18","time":"2023-09-11T14:12:00+06:00"},{"station":"17","time":"2023-09-11T14:14:00+06:00"}],"bus":"Ba-24-8518"},]);
});

//get trip data
app.post('/api/getTripData', (req,res) => {
    //send a dummy response
    console.log(req.body);
    res.send({
        success: true,
        ...tracking.runningTrips.get(req.body.trip_id),
    });
});

//get trip data
app.post('/api/getStaffTrips', (req,res) => {
    //send a dummy response
    if (req.session.userid && req.session.user_type=="bus_staff") {
        console.log(req.body);
        dbclient.query(
            `select * from allocation where is_done=false and (driver=$1 or helper=$1)`, 
            [req.session.userid]
        ).then(qres => {
            console.log(qres);
            dbclient.query(
                `select * from trip where (driver=$1 or helper=$1)`, 
                [req.session.userid]
            ).then(qres2 => {
                console.log(qres2);
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
        dbclient.query(
            `call initiate_trip($1, $2)`, 
            [req.body.trip_id, req.session.userid]
        ).then(qres => {
            // console.log(qres);
            dbclient.query(
                `select *, array_to_json(time_list) as time_list_ from trip where id=$1`, 
                [req.body.trip_id]
            ).then(qres2 => {
                // console.log(qres2);
                if (qres2.rows.length == 1) {
                    let td = {...qres2.rows[0]};
                    let newTrip = new tracking.RunningTrip 
                       (td.id, td.start_timestamp, td.route, td.time_type, 
                        td.travel_direction, td.bus, td.is_default,
                        td.bus_staff, td.approved_by, td.end_timestamp,
                        td.start_location, td.end_location);
                    tracking.runningTrips.set (newTrip.id, newTrip);
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

            // if (qres.command == 'CALL') res.send({ 
            //     success: true,
            // });
            // else {
            //     res.send({
            //         success: false,
            //     });
            // };
        }).catch(e => console.error(e.stack));
    };
});

app.post('/api/endTrip', (req,res) => {
    if (req.session.userid && req.session.user_type=="bus_staff") {
        let trip = tracking.runningTrips.get(req.body.trip_id);
        dbclient.query(
            `update trip set end_timestamp=current_timestamp, passenger_count=$1, end_location[0]=$2, end_location[1]=$3, 
             is_live=false where id=$4 and (driver=$5 or helper=$5)`, 
            [trip.passenger_count, req.body.latitude, req.body.longitude, req.body.trip_id, req.session.userid]
        ).then(qres => {
            console.log(qres);
            if (qres.rowCount === 1) res.send({ 
                success: true,
            });
            else if (qres.rowCount === 0) {
                res.send({
                    success: false,
                });
            };
        }).catch(e => console.error(e.stack));
        tracking.runningTrips.delete(req.body.trip_id);
    };
});

app.post('/api/updateStaffLocation', (req,res) => {
    //send a dummy response
    if (req.session.userid && req.session.user_type=="bus_staff") {
        console.log(req.body);
        tracking.runningTrips.get(req.body.trip_id).path.push({
            latitude: req.body.latitude, 
            longitude: req.body.longitude
        });
        res.send({
            success: true,
            // new_path: [
            //     { "latitude": 23.7651, "longitude": 90.3652 },
            //     { "latitude": 23.7652, "longitude": 90.3650 },
            //     { "latitude": 23.7650, "longitude": 90.3651 },
            // ]
        });
    };
});

app.post('/api/updateTripT', (req,res) => {
    //send a dummy response
    console.log(pd.trip_t);
    let pathStr = "{";
    for (let i=0; i<trip_t.path.length; i++) {
        pathStr += `"(${trip_t.path[i].latitude}, ${trip_t.path[i].longitude})"`;
        if (i<trip_t.path.length-1) pathStr += ", ";
    };
    pathStr += "}";
    console.log(pathStr);
    dbclient.query(
        `update trip set passenger_count=$1, is_live=false, path=$4 where id=$2 and (driver=$3 or helper=$3)`, 
        [trip_t.passenger_count, trip_t.id, 'altaf', pathStr]
    ).then(qres => {
        console.log(qres);
        if (qres.rowCount === 1) res.send({ 
            success: true,
        });
        else if (qres.rowCount === 0) {
            res.send({
                success: false,
            });
        };
    }).catch(e => console.error(e.stack));
    tracking.runningTrips.delete(req.body.trip_id);
});

app.post('/api/staffScanTicket', (req,res) => {
    //send a dummy response
    if (req.session.userid && req.session.user_type=="bus_staff") {
        console.log(req.body);
        dbclient.query(
            `update ticket set trip_id=$1, is_used=true where id=$2 returning student_id`, 
            [trip.passenger_count, trip.end_location.latitude, trip.end_location.longitude, req.body.trip_id, req.session.userid]
        ).then(qres => {
            console.log(qres);
            if (qres.rowCount === 1) res.send({ 
                success: true,
                student_id: qres.rows[0].student_id
            });
            else if (qres.rowCount === 0) {
                res.send({
                    success: false,
                });
            };
        }).catch(e => console.error(e.stack));
    };
});

app.listen(port, () => {
    console.log(`BudBuddy backend listening on port ${port}`);
});
