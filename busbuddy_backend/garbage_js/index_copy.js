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

const getSHA256 = (input) => {
    return crypto.createHash('sha256').update(JSON.stringify(input)).digest('hex');
};

const getSHA512 = (input) => {
    return crypto.createHash('sha512').update(JSON.stringify(input)).digest('hex');
};

const getMD5 = (input) => {
    return crypto.createHash('md5').update(JSON.stringify(input)).digest('hex');
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
const e = require('express');

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
        if (qres.rows.length === 0) res.send({ 
            success: false,
            name: null
        });
        else {
            req.session.userid = req.body.id;
            res.send({
                success: true,
                name: qres.rows[0].name,
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
    };
});

app.post('/api/getProfileStatic', (req, res) => {
    console.log(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select id, name from student where id=$1`, 
            [req.session.userid]
        ).then(qres => {
            //console.log(qres);
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

app.post('/api/updatePassword', (req,res) => {
    dbclient.query(
        `UPDATE customer SET password=$1 WHERE mobile=$2 AND password=$3`, 
        [req.body.password, req.session.userid, req.body.password0]
    ).then(qres => {
        //console.log(qres);
        if (qres.rowCount === 1) res.send({ 
            success: true,
        });
        else if (qres.rowCount === 0) {
            res.send({
                success: false,
            });
        };
    }).catch(e => console.error(e.stack));
});

app.post('/api/getRoutes', (req,res) => {
    console.log("sending route data");
    dbclient.query("SELECT id, terminal_point FROM route").then(qres => {
        res.send(qres.rows);
    }).catch(e => console.error(e.stack));
});


app.post('/api/getStations', (req,res) => {
    console.log("sending station data");
    dbclient.query("SELECT id, name FROM station").then(qres => {
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

app.post('/api/addStudentFeedback', (req,res) => {
    console.log(req.body);
    if (req.session.userid) {
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

app.post('/api/getUserFeedback', (req, res) => {
    console.log(req.session);
    if (req.session.userid) {
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
             from upcoming_trip where route=$1`, [req.body.route]
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

//============== RAILBUDDY  | =========
//                          V
app.post('/api/getStations', (req,res) => {
    dbclient.query("SELECT id, name, district, coords FROM station WHERE id < 900 ORDER BY district ASC, name ASC").then(qres => {
        res.send(qres.rows);
    }).catch(e => console.error(e.stack));
});

app.post('/api/getTracks', (req,res) => {
    dbclient.query("SELECT track_array FROM tracks").then(qres => {
        res.send(qres.rows);
    }).catch(e => console.error(e.stack));
});

app.post('/api/getTrains', (req,res) => {
    dbclient.query("SELECT distinct on (name) id, name FROM train ORDER BY name ASC, id ASC").then(qres => {
        res.send(qres.rows);
    }).catch(e => console.error(e.stack));
});

app.post('/api/getClasses', (req,res) => {
    dbclient.query("SELECT unnest(enum_range(NULL::seat_class));").then(qres => {
        let nameArr = [];
        qres.rows.forEach(obj => { nameArr.push(obj.unnest) });
        res.send(nameArr);
    }).catch(e => console.error(e.stack));
});

app.post('/api/getCompTypes', (req,res) => {
    dbclient.query("SELECT unnest(enum_range(NULL::complaint_category));").then(qres => {
        let nameArr = [];
        qres.rows.forEach(obj => { nameArr.push(obj.unnest) });
        res.send(nameArr);
    }).catch(e => console.error(e.stack));
});

app.post('/api/getRqstTypes', (req,res) => {
    if (req.session.userid) {
        dbclient.query("SELECT unnest(enum_range(NULL::request_category));").then(qres => {
            let nameArr = [];
            qres.rows.forEach(obj => { nameArr.push(obj.unnest) });
            res.send(nameArr);
        }).catch(e => console.error(e.stack));
    } else res.send(["Foreigner Account Registration", "Reclaim Occupied NID for New Account"]);
});

app.post('/api/getComplaints', (req, res) => {
    console.log(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select *, lpad(id::varchar, 8, '0')::char(8) as complaint_id, get_station_name(associated_station) as a_st_name, 
            get_train_name(associated_train) as a_tr_name from complaint where user_mobile=$1
            order by req_time desc limit 10`, [req.session.userid]
        ).then(qres => {
            //console.log(qres);
            if (qres.rowCount === 0) res.send({ 
                success: false,
            });
            else {
                res.send({
                    complaints: [...qres.rows],
                    success: true,
                });
            };
        }).catch(e => console.error(e.stack));
    };
});

app.post('/api/getComplaintsAdmin', (req, res) => {
    console.log (req.body);
    console.log('ehfrgeighiuhvhe');
    
    if (req.session.adminid) {
        dbclient.query(`SELECT *, lpad(id::varchar, 8, '0')::char(8) as complaint_id from complaint join customer on complaint.user_mobile = customer.mobile;`,
        ).then(qres => {
            if (qres.rows.length === 0){
                res.send ( {success: false} );
            }
            else res.send ( {
                success: true, 
                route: qres.rows
                
            });
        }).catch(e => console.error(e.stack));
    }
});


app.post('/api/getRequestsAdmin', (req, res) => {
    console.log (req.body);
    console.log('ehfrgeighiuhvhe');
    if (req.session.adminid) {
        dbclient.query(`SELECT *, lpad(id::varchar, 8, '0')::char(8) as request_id from request join customer on request.user_mobile = customer.mobile;`,
        ).then(qres => {
            let reqObj = [...qres.rows];
            for (r of reqObj) r.doc = null;
            if (qres.rows.length === 0){
                res.send ( {success: false} );
            }
            else res.send ( {
                success: true, 
                route: qres.rows
                
            });
        }).catch(e => console.error(e.stack));
    }
});

// app.post('/api/getRequests', (req, res) => {
//     console.log(req.session);
//     if (req.session.userid) {
//         dbclient.query(
//             `select *, lpad(id::varchar, 8, '0')::char(8) as request_id, category as cat, 
//             from request where user_mobile=$1
//             order by req_time desc limit 10`, [req.session.userid]
//         ).then(qres => {
//             //console.log(qres);
//             if (qres.rowCount === 0) res.send({ 
//                 success: false,
//             });
//             else {
//                 res.send({
//                     complaints: [...qres.rows],
//                     success: true,
//                 });
//             };
//         }).catch(e => console.error(e.stack));
//     };
// });

app.post('/api/setCompSeen', (req, res) => {
    console.log(req.session);
    if (req.session.userid) {
        dbclient.query(
            `update complaint set res_seen=true where id=$1 AND user_mobile=$2`, 
            [req.body.complaint_id, req.session.userid]
        ).then(qres => {
            //console.log(qres);
            if (qres.rowCount === 0) res.send({ 
                success: false,
            });
            else {
                res.send({
                    success: true,
                });
            };
        }).catch(e => console.error(e.stack));
    };
});

app.post('/api/getClosestStation', (req, res) => {
    console.log(req.body);
    dbclient.query(
        `select id from station where id<900 order by ((coords[0]-$1)^2 + (coords[1]-$2)^2) limit 1`, 
        [req.body.lat, req.body.lng]
    ).then(qres => {
        //console.log(qres);
        if (qres.rowCount === 0) res.send({ 
            success: false,
        });
        else {
            res.send({
                station_id: qres.rows[0].id,
                success: true,
            });
        };
    }).catch(e => console.error(e.stack));
});

app.post('/api/getRequests', (req, res) => {
    console.log(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select *, lpad(id::varchar, 8, '0')::char(8) as request_id 
            from request where user_mobile=$1 order by req_time desc limit 10`, [req.session.userid]
        ).then(qres => {
            //console.log(qres);
            if (qres.rowCount === 0) res.send({ 
                success: false,
            });
            else {
                let reqObj = [...qres.rows];
                for (r of reqObj) r.doc = null;
                console.log(reqObj);
                //for (const rq of reqObj) rq.doc = Buffer.from(rq.doc.data);
                res.send({
                    requests: [...reqObj],
                    success: true,
                });
            };
        }).catch(e => console.error(e.stack));
    };
});



app.post('/api/makeRequest', multer().single('doc'), (req,res) => {
    // console.log(req.body);
    // fs.writeFileSync("src/" + req.file.originalname, req.file.buffer);
    if (req.session.userid) {
        dbclient.query(
            `INSERT INTO request (category, user_mobile, req_time, req_text, doc, docname) values ($1, $2, NOW(), $3, $4, $5)`, 
            [req.body.category, req.session.userid, req.body.text, req.file.buffer, req.file.originalname]
        ).then(qres => {
            //console.log(qres);
            if (qres.rowCount === 1) res.send({ 
                success: true,
            });
            else if (qres.rowCount === 0) {
                res.send({
                    success: false,
                });
            };
        }).catch(e => console.error(e.stack));
    } else {
        dbclient.query(
            `INSERT INTO request (category, user_mobile, req_time, req_text, doc, docname) values ($1, $2, NOW(), $3, $4, $5)`, 
            [req.body.category, "ANONYMOUS", req.body.text, req.file.buffer, req.file.originalname]
        ).then(qres => {
            //console.log(qres);
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

app.post('/api/search', (req, res) => {
    if ((new Date(req.body.date)).toISOString().substring(0,10) == getRealISODate()) {
        console.log ("searching trains after NOW");
        dbclient.query(`select *, next_journey_arrival(id, $1, $2, NOW()), next_departure(id, $1, NOW()), 
                        train_has_class(id, $3) as has_desired_class from train 
                        where id in (select tr_id from connecting_trains($1, $2, NOW()))`,
                        [req.body.from, req.body.to, req.body.class]
        ).then(qres => {
            if (qres.rows.length === 0) res.send ( {success: false} );
            else res.send ( {success: true, trains: qres.rows});
        }).catch(e => console.error(e.stack));
    } else {
        console.log ("searching trains after" + req.body.date);
        dbclient.query(`select *, next_journey_arrival(id, $1, $2, $3::timestamp), next_departure(id, $1, $3::timestamp), 
                        train_has_class(id, $4) as has_desired_class from train 
                        where id in (select tr_id from connecting_trains($1, $2, $3::timestamp))`,
                        [req.body.from, req.body.to, req.body.date, req.body.class]
        ).then(qres => {
            if (qres.rows.length === 0) res.send ( {success: false} );
            else res.send ( {success: true, trains: qres.rows});
        }).catch(e => console.error(e.stack));
    }
}); 

app.post('/api/searchConnections2', (req, res) => {
    if ((new Date(req.body.date)).toISOString().substring(0,10) == getRealISODate()) {
        console.log ("searching trains after NOW");
        dbclient.query(`select distinct on (tot_time) *, (ar2-de1) as tot_time, get_station_name(md_st) as md_st_name,
                        (de2-ar1) as transit, abs(extract(epoch from (ar2-de2)) - extract(epoch from (ar1-de1))) as leg_diff
                        from connecting_trains_2 ($1, $2, NOW()) order by tot_time, leg_diff`, [req.body.from, req.body.to]
        ).then(qres => {
            if (qres.rows.length === 0) res.send ( {success: false} );
            else {
                res.send ( {success: true, routes: qres.rows});
            };
        }).catch(e => console.error(e.stack));
    } else {
        console.log ("searching trains after" + req.body.date);
        dbclient.query(`select distinct on (tot_time) *, (ar2-de1) as tot_time, get_station_name(md_st) as md_st_name,
                        (de2-ar1) as transit, abs(extract(epoch from (ar2-de2)) - extract(epoch from (ar1-de1))) as leg_diff
                        from connecting_trains_2 ($1, $2, $3) order by tot_time, leg_diff`, [req.body.from, req.body.to, req.body.date]
        ).then(qres => {
            if (qres.rows.length === 0) res.send ( {success: false} );
            else res.send ( {success: true, routes: qres.rows});
        }).catch(e => console.error(e.stack));
    }
}); 

app.post('/api/searchConnections3', (req, res) => {
    if ((new Date(req.body.date)).toISOString().substring(0,10) == getRealISODate()) {
        console.log ("searching trains after NOW");
        dbclient.query(`select distinct on (tot_time) *,
                        (ar3-de1) as tot_time, get_station_name(md_st1) as md_st1_name, get_station_name(md_st2) as md_st2_name,
                        abs( extract(epoch from (ar1-de1)) - (extract(epoch from (ar1-de1))+extract(epoch from (ar2-de2))+extract(epoch from (ar3-de3)))/3 ) +
                        abs( extract(epoch from (ar2-de2)) - (extract(epoch from (ar1-de1))+extract(epoch from (ar2-de2))+extract(epoch from (ar3-de3)))/3 ) +
                        abs( extract(epoch from (ar3-de3)) - (extract(epoch from (ar1-de1))+extract(epoch from (ar2-de2))+extract(epoch from (ar3-de3)))/3 ) as mean_dev
                        from connecting_trains_3 ($1, $2, NOW())
                        order by tot_time, mean_dev`, [req.body.from, req.body.to]
        ).then(qres => {
            if (qres.rows.length === 0) res.send ( {success: false} );
            else {
                res.send ( {success: true, routes: qres.rows});
            };
        }).catch(e => console.error(e.stack));
    } else {
        console.log ("searching trains after" + req.body.date);
        dbclient.query(`select distinct on (tot_time) *,
                        (ar3-de1) as tot_time, get_station_name(md_st1) as md_st1_name, get_station_name(md_st2) as md_st2_name,
                        abs( extract(epoch from (ar1-de1)) - (extract(epoch from (ar1-de1))+extract(epoch from (ar2-de2))+extract(epoch from (ar3-de3)))/3 ) +
                        abs( extract(epoch from (ar2-de2)) - (extract(epoch from (ar1-de1))+extract(epoch from (ar2-de2))+extract(epoch from (ar3-de3)))/3 ) +
                        abs( extract(epoch from (ar3-de3)) - (extract(epoch from (ar1-de1))+extract(epoch from (ar2-de2))+extract(epoch from (ar3-de3)))/3 ) as mean_dev
                        from connecting_trains_3 ($1, $2, $3)
                        order by tot_time, mean_dev`, [req.body.from, req.body.to, req.body.date]
        ).then(qres => {
            if (qres.rows.length === 0) res.send ( {success: false} );
            else res.send ( {success: true, routes: qres.rows});
        }).catch(e => console.error(e.stack));
    };
}); 

app.post('/api/getConnTrains', (req, res) => {
    console.log ("searching trains after NOW");
    if (typeof req.body.tr_id3 === 'undefined') {
        dbclient.query(`select * from train where id = $1 or id = $2`, [req.body.tr_id1, req.body.tr_id2]
        ).then(qres => {
            if (qres.rows.length === 0) res.send ( {success: false} );
            else res.send ( {success: true, trains: qres.rows});
        }).catch(e => console.error(e.stack));
    } else {
        dbclient.query(`select * from train where id = $1 or id = $2 or id = $3`, [req.body.tr_id1, req.body.tr_id2, req.body.tr_id3]
        ).then(qres => {
            if (qres.rows.length === 0) res.send ( {success: false} );
            else res.send ( {success: true, trains: qres.rows});
        }).catch(e => console.error(e.stack));
    };
}); 

app.post('/api/getCoaches', (req, res) => {
    console.log (req.body);
    dbclient.query(`select distinct on (class_name) class_id, class_name, fare, get_capacity(class_id) as capacity, 
                    get_vacancy(class_id, $2) as vacancy from (select * from bogie order by fare desc) bogie where train_id=$1`,
    [req.body.id, req.body.date]
    ).then(qres => {
        dbclient.query(`SELECT station_id, station_name from route_detail ($1, $2, $3, $4::timestamp);`,
        [req.body.id, req.body.st1_id, req.body.st2_id, req.body.date]
        ).then(qres2 => {
            if (qres.rows.length === 0 || qres.rows.length === 0 ) res.send ( {success: false} );
            else res.send ( {success: true, route: qres2.rows, classes: qres.rows});
        }).catch(e => console.error(e.stack));
    }).catch(e => console.error(e.stack));
}); 

app.post('/api/checkSeats', (req, res) => {
    console.log (req.body);

    dbclient.query(`select seat_config.coach, mat_row, mat_col, mat, vacancy 
                    from seat_config join get_vacancy_matrices($1, $2) as occdate 
                    on seat_config.coach = occdate.coach 
                    where class_id=$1`,
    [req.body.class_id, req.body.date]
    ).then(qres => {
        if (qres.rows.length === 0) res.send ( {success: false} );
        else res.send ( {success: true, bogies: qres.rows});
    }).catch(e => console.error(e.stack));
}); 

app.post('/api/initPurchase', (req, res) => {
    const t_no = req.body.seatList.length;
    console.log(req.body, t_no);
    if (req.session.userid && t_no <= 4 && t_no >= 0) { 
        dbclient.query('select count(*) from purchases where mobile=$1 and date(timestamp)=$2', 
        [req.session.userid, getRealISODate(new Date())]
        ).then(fqres => {
            if (fqres.rows[0].count <3) {
                console.log("Initiating purchase...");
                let p_ids=Array(t_no), p_names=Array(t_no), L=Array(t_no), r=Array(t_no), c=Array(t_no);
                for (let i=0; i<t_no; i++) {
                    p_ids[i] = req.body.seatList[i].pid, p_names[i] = req.body.seatList[i].pname, L[i] = req.body.seatList[i].L;
                    r[i] = req.body.seatList[i].r + 1, c[i] = req.body.seatList[i].c + 1;
                };
                console.log('hello');
                dbclient.query(`select init_purchase($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) as purchase_id`, [   
                    req.session.userid, p_ids, p_names, req.body.class_id, L, 
                    req.body.date, r, c, req.body.bStation,t_no,
                ]).then(qres => {
                    //console.log(qres);
                    let purchase_id = qres.rows[0].purchase_id;
                    res.send(url.format({
                        pathname: '/api/initPayment',
                        query: {
                            'tran_id': purchase_id, 
                            'num_of_item': t_no,
                            'value_a': req.body.qString,
                            'value_c': req.body.hostname
                        }
                    }));
                }).catch(e => console.error(e));
            } else res.send({
                success: false,
                quota : "full"
            });
        }).catch(e => console.error(e));
    };
});

app.get('/api/initPayment', (req, res) => {
    console.log(req.session);
    if (req.session.userid) {
        let data = {...req.query};
        dbclient.query(`select price, class_id, uuid, payment_status, mobile, 
                        (select name from customer as c where c.mobile=p.mobile) as cus_name from purchases as p
                        where purchase_id=$1`, [req.query.tran_id
        ]).then(qres2 => {
            if (req.session.userid === qres2.rows[0].mobile && qres2.rows[0].payment_status === "initiated") {
                data.total_amount = qres2.rows[0].price;
                data.currency = 'BDT',
                data.success_url = req.query.value_c + "/api/pay_success";
                data.fail_url = req.query.value_c + "/api/pay_fail";
                data.cancel_url = req.query.value_c + "/api/pay_cancel";
                data.shipping_method = 'NO';
                data.product_name = "Ticket for " + qres2.rows[0].class_id;
                data.product_category = 'train ticket';
                data.product_profile = 'non-physical-goods';
                data.cus_name = qres2.rows[0].cus_name;
                data.cus_email = process.env.SSLCZ_EMAIL_DEMO;
                data.cus_phone = req.session.userid;
                data.value_b = qres2.rows[0].uuid;
                data.value_d = qres2.rows[0].mobile;

                const sslcz = new SSLCommerzPayment(store_id, store_passwd, is_live)
                sslcz.init(data).then(apiResponse => {
                    // Redirect the user to payment gateway
                    //console.log(apiResponse);
                    let GatewayPageURL = apiResponse.GatewayPageURL
                    console.log(req.session);
                    res.redirect(GatewayPageURL);
                    console.log(req.session);
                    console.log('Redirecting to: ', GatewayPageURL);
                });
            } else res.redirect('/pay_fail');
        }).catch(e => console.error(e));
    } else res.redirect('/pay_fail');
});

app.post('/api/pay_success', (req, res) => {
    // console.log(req);
    // console.log(req.session);
    dbclient.query(
        `SELECT uuid FROM purchases WHERE purchase_id=$1 AND mobile=$2 AND payment_status=$3`, 
        [req.body.tran_id, req.body.value_d, 'initiated']
    ).then(qres => {
        if (qres.rows[0].uuid === req.body.value_b) {
            let pmethod = `${req.body.card_type} ${req.body.card_no} : ${req.body.card_issuer_country}`;
            dbclient.query(
                `UPDATE purchases SET payment_status=$1, payment_method=$2, val_id=$3, trx_timestamp=$4, revenue=$5, trx_id=$7, uuid=$8
                WHERE purchase_id = $6`, 
                ["confirmed", pmethod, req.body.val_id, req.body.tran_date, req.body.store_amount, req.body.tran_id, req.body.bank_tran_id, uuidv4()]
            ).then(qres2 => {
                // console.log(qres);
                // console.log(req.session);
                req.session.save(() => {
                    // console.log(req.session);
                    req.session.userid = req.body.value_d;
                    // console.log(req.session);
                    res.redirect('/pay_success' + req.body.value_a + "&pid=" + req.body.tran_id);
                    // console.log(req.session);
                });
                console.log(req.session);
            }).catch(e => console.error(e.stack));
        } else res.redirect('/pay_fail');
    }).catch(e => console.error(e.stack));
});

app.post('/api/pay_fail', (req, res) => {
    dbclient.query(
        `SELECT uuid FROM purchases WHERE purchase_id=$1 AND mobile=$2 AND payment_status=$3`, 
        [req.body.tran_id, req.body.value_d, 'initiated']
    ).then(qres => {
        if (qres.rows[0].uuid === req.body.value_b) {
            let pmethod = `${req.body.card_type} ${req.body.card_no} : ${req.body.card_issuer_country}`;
            dbclient.query(
                `call revert_purchase($1)`, [req.body.tran_id]
            ).then(qres2 => {
                // console.log(qres);
                // console.log(req.session);
                req.session.save(() => {
                    // console.log(req.session);
                    req.session.userid = req.body.value_d;
                    // console.log(req.session);
                    res.redirect('/pay_fail' + req.body.value_a);
                    // console.log(req.session);
                });
                console.log(req.session);
            }).catch(e => console.error(e.stack));
        } else res.redirect('/pay_fail');
    }).catch(e => console.error(e.stack));
});

app.post('/api/pay_cancel', (req, res) => {
    dbclient.query(
        `SELECT uuid FROM purchases WHERE purchase_id=$1 AND mobile=$2 AND payment_status=$3`, 
        [req.body.tran_id, req.body.value_d, 'initiated']
    ).then(qres => {
        if (qres.rows[0].uuid === req.body.value_b) {
            let pmethod = `${req.body.card_type} ${req.body.card_no} : ${req.body.card_issuer_country}`;
            dbclient.query(
                `call revert_purchase($1)`, [req.body.tran_id]
            ).then(qres2 => {
                // console.log(qres);
                // console.log(req.session);
                req.session.save(() => {
                    // console.log(req.session);
                    req.session.userid = req.body.value_d;
                    // console.log(req.session);
                    res.redirect('/pay_cancel' + req.body.value_a);
                    // console.log(req.session);
                });
                console.log(req.session);
            }).catch(e => console.error(e.stack));
        } else res.redirect('/pay_fail');
    }).catch(e => console.error(e.stack));
});

app.post('/api/getPurchases', (req, res) => {
    console.log(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select (select distinct get_train_name(train_id) from bogie as B where B.class_id=P.class_id) as train_name,
            (select distinct class_name from bogie as B where B.class_id=P.class_id) as class_name, *
            from purchases as P where mobile=$1 order by timestamp desc`, [req.session.userid]
        ).then(qres => {
            //console.log(qres);
            if (qres.rows.length === 0) res.send({ 
                success: false,
            });
            else {
                res.send({
                    history: [...qres.rows],
                    success: true,
                });
            };
        }).catch(e => console.error(e.stack));
    };
});

app.post('/api/getPurchaseDetails', (req, res) => {
    console.log(req.session);
    if (req.session.userid) {
        dbclient.query(
            `select ticket_id, name, person_id, 
            (coach_letter || '-' || (select mat[seat_row][seat_col] 
                                     from seat_config 
                                     where class_id=substring(purchase_id::varchar, 1, 8)::int AND coach=coach_letter)) 
                                     as seat
            from tickets where purchase_id = $1`, [req.body.purchase_id]
        ).then(qres => {
            //console.log(qres);
            if (qres.rows.length === 0) res.send({ 
                success: false,
            });
            else {
                res.send({
                    tickets: [...qres.rows],
                    success: true,
                });
            };
        }).catch(e => console.error(e.stack));
    };
});

app.post('/api/ticketVerif', (req, res) => {
    let qStr = "";
    if (req.body.id.length === 29) 
        qStr = `select (select distinct get_train_name(train_id) from bogie as B where B.class_id=P.class_id) as train_name,
                (select distinct class_name from bogie as B where B.class_id=P.class_id) as class_name, *
                from purchases as P where mobile=$1 AND purchase_id=$2`;
    else if (req.body.id.length === 26) 
        qStr = `select (select distinct get_train_name(train_id) from bogie as B where B.class_id=P.class_id) as train_name,
                (select distinct class_name from bogie as B where B.class_id=P.class_id) as class_name, *
                from purchases as P where mobile=$1 AND 
                        purchase_id = (select purchase_id from tickets where ticket_id=$2)`;
    if (req.body.id.length === 29 || req.body.id.length === 26) {
        dbclient.query(qStr, [req.body.mobile, req.body.id]).then(qres => {
            console.log(qres.rows);
            if (qres.rows.length === 0) res.send({ 
                success: false,
            });
            else {
                dbclient.query(
                    `select ticket_id, name, person_id, 
                    (coach_letter || '-' || (select mat[seat_row][seat_col] 
                                             from seat_config 
                                             where class_id=substring(purchase_id::varchar, 1, 8)::int AND coach=coach_letter)) 
                                             as seat
                    from tickets where purchase_id = $1`, [qres.rows[0].purchase_id]
                ).then(qres2 => {
                    //console.log(qres);
                    if (qres2.rows.length === 0) res.send({ 
                        success: false,
                    });
                    else {
                        res.send({
                            purchase: {...qres.rows[0], tickets: [...qres2.rows]},
                            success: true,
                        });
                    };
                }).catch(e => console.error(e.stack));
            };
        }).catch(e => console.error(e.stack));
    } else res.send({ 
        success: false,
    });
});

app.get('/api/getTicketPDF', (req, res) => {
    if (req.session.userid) {
        dbclient.query(
           `SELECT  get_train_name(train_id) as train_name,
                    (coach_letter || '-' || (select mat[seat_row][seat_col] 
                                            from seat_config as SC
                                            where class_id=substring(ticket_id::varchar, 1, 8)::int AND coach=coach_letter)) as seat,
                    substring(ticket_id, 23)::int as bStation, get_station_name(substring(ticket_id, 23)::int) as bStation_name, 
                    dest as dStation, get_station_name(dest) as dStation_name, tickets.name as buyername,
                    to_char(price * 0.15, '99G99G999D99') as vat, to_char(price / 1.15, '99G99G999D99') as base,
                    to_char(next_departure(train_id, substring(ticket_id, 23)::int, day_of_travel), 'HH12:MIAM') as departure, *
            FROM
                tickets JOIN purchases on (purchases.purchase_id = tickets.purchase_id) 
                        JOIN bogie on (bogie.class_id = purchases.class_id) 
                        JOIN train on (train.id = bogie.train_id)
            WHERE ticket_id=$1 AND mobile=$2`, [req.query.tid, req.session.userid]
        ).then(qres => {
            console.log(qres.rows);
            if (qres.rows.length === 0) res.send("User login is required to access the ticket.");
            else {
                let t = qres.rows[0];
                t.day_of_travel = (new Date(t.day_of_travel)).toDateString();
                t.timestamp = (new Date(t.timestamp)).toLocaleString();
                t.qrURL = `https://chart.googleapis.com/chart?chs=250x250&cht=qr&chl=http://harmony-open.com:6984/verif?tid=${t.ticket_id}%26u=${t.mobile}`
                let document = { html: html, data: { t: t }, path: "./output.pdf", type: "stream" };
                pdf.create(document, {
                    height: "1080px",
                    width: "764px",
                }).then(pres => {
                    console.log(pres);
                    res.setHeader('Content-Type', 'application/pdf');
                    res.setHeader('Content-Disposition', 'inline; filename=RailBuddy_' + t.ticket_id + '.pdf');
                    pres.pipe(res);
                }).catch(e => console.error(e.stack));
            };
        }).catch(e => console.error(e.stack));
    } else res.send("User login is required to access the ticket.");
});

app.get('/api/getUserDoc', (req, res) => {
    if (req.session.userid) {
        dbclient.query(
           `SELECT doc, docname FROM request WHERE id=$1 and user_mobile=$2`,  
           [Number(req.query.rid), req.session.userid]
        ).then(qres => {
            console.log(qres.rows);
            if (qres.rows.length > 0) {
                const stream = Readable.from(qres.rows[0].doc);
                // res.setHeader('Content-Type', 'application/pdf');
                res.setHeader('Content-Disposition', 'inline; filename=' + qres.rows[0].docname);
                stream.pipe(res);
            } else res.send("User/admin login is required to access the ticket.");
        }).catch(e => console.error(e.stack));
    } else if (req.session.adminid) {
        dbclient.query(
           `SELECT doc, docname FROM request WHERE id=$1`,  
           [Number(req.query.rid)]
        ).then(qres => {
            console.log(qres.rows);
            if (qres.rows.length > 0) {
                const stream = Readable.from(qres.rows[0].doc);
                // res.setHeader('Content-Type', 'application/pdf');
                res.setHeader('Content-Disposition', 'inline; filename=' + qres.rows[0].docname);
                stream.pipe(res);
            } else res.send("User/admin login is required to access the ticket.");
        }).catch(e => console.error(e.stack));
    } else res.send("User/admin login is required to access the ticket.");
});


app.post('/api/getRoute', (req, res) => {
    console.log (req.body);
    if ((new Date(req.body.date)).toISOString().substring(0,10) == (new Date()).toISOString().substring(0,10)) {
        dbclient.query(`SELECT * from route_detail ($1, $2, $3, NOW());`,
        [req.body.train_id, req.body.st1_id, req.body.st2_id]
        ).then(qres => {
            if (qres.rows.length === 0) res.send ( {success: false} );
            else res.send ( {success: true, route: qres.rows});
        }).catch(e => console.error(e.stack));
    } else {
        dbclient.query(`SELECT * from route_detail ($1, $2, $3, $4::timestamp);`,
        [req.body.train_id, req.body.st1_id, req.body.st2_id, req.body.date]
        ).then(qres => {
            if (qres.rows.length === 0) res.send ( {success: false} );
            else res.send ( {success: true, route: qres.rows});
        }).catch(e => console.error(e.stack));
    }
}); 

app.post('/api/validateSendNewMobileOTP', (req, res) => {
    if (req.session.userid) {
        console.log(req.body);
        dbclient.query(
            `SELECT COUNT(*) FROM customer WHERE mobile=$1 AND password=$2`,
            [req.session.userid, req.body.password]
        ).then(qres => {
            //console.log(qres);
            if (qres.rows[0].count == '0') res.send({ 
                success: false,
            });
            else {
                req.session.pwdChangeValidity = getSHA256(req.session.userid + process.env.CHANGE_SECRET);
                res.send({
                    success: true,
                });
                console.log(req.session);
            };
        }).catch(e => console.error(e.stack));
    } else {
        req.session.destroy();
        res.send({ 
            success: false,
        });
    };
});

app.post('/api/sendNewMobileOTP', (req, res) => {
    if (req.session.userid && req.session.pwdChangeValidity == getSHA256(req.session.userid + process.env.CHANGE_SECRET)) {
        dbclient.query (
            "CALL UPSERT_OTP($2, $1); ",
            [otpGenerator.generate(6, {
                upperCaseAlphabets: false,
                lowerCaseAlphabets: false,
                specialChars: false
            }), req.body.newMobile]
        ).then(qres2 => {
            console.log(qres2);
            res.send({
                success: true,
            });
        }).catch(e => console.error(e.stack));
    } else {
        req.session.destroy();
        res.send({ 
            success: false,
        });
    };
});


app.post('/api/changePassword', (req, res) => {
    if (req.session.userid && req.session.pwdChangeValidity == getSHA256(req.session.userid + process.env.CHANGE_SECRET)) {
        console.log(req.body);
        dbclient.query (
            "UPDATE customer SET mobile=$1 where mobile=$2 AND password=$3 AND (SELECT otp FROM otp WHERE mobile=$1) = $4",
            [req.body.newMobile, req.session.userid, req.body.password, req.body.otp]
        ).then(qres => {
            console.log(qres);
            if (qres.rowCount === 1) res.send({ 
                success: true,
            });
            else if (qres.rowCount === 0) res.send({ 
                success: false,
            });
        }).catch(e => {
            console.error(e.stack);
            res.send({ 
                success: false,
            });
        });
    } else {
        req.session.destroy();
        res.send({ 
            success: false,
        });
    };
});




app.post('/api/setOffset', (req, res) => {
    console.log (req.body);
    dbclient.query(`call update_schedule($1,$2, $3::interval)`,
    [req.body.train, req.body.date, req.body.interval]
    ).then(qres => {
        res.send({
            success: true,
        });
        
    }).catch(e => console.error(e));
});

app.post('/api/sendReply', (req, res) => {
    console.log (req.body);
    console.log('ehfrgeighiuhvhe');
    if (req.session.adminid) {
        dbclient.query(`UPDATE complaint SET res_text = $1, res_time = current_timestamp WHERE id = $2`,
        [req.body.reply, req.body.id]
        ).then(qres => {
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
});

app.post('/api/sendResponse', (req, res) => {
    console.log (req.body);
    console.log('ehfrgeighiuhvhe');
    if (req.session.adminid) {
        dbclient.query(`UPDATE request SET res_text = $1, res_time = current_timestamp WHERE id = $2`,
        [req.body.reply, req.body.id]
        ).then(qres => {
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
});

app.post('/api/postNotice', (req, res) => {
    console.log (req.body);
    console.log('ehfrgeighiuhvhe');
    if (req.session.adminid) {
        dbclient.query(`INSERT INTO notice(title,text,time_posted,valid_until, admin_id) VALUES($1,$2,NOW(),$3::timestamp,$4)`,
        [req.body.title, req.body.text, req.body.vt, req.session.adminid]
        ).then(qres => {
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
});

app.post('/api/getNotices', (req,res) => {
    dbclient.query("SELECT title, text, time_posted FROM notice ORDER BY time_posted DESC").then(qres => {
        res.send(qres.rows);
    }).catch(e => console.error(e.stack));
});


app.use(express.static(path.resolve(__dirname, '../railbuddy-client/dist')));

app.get('*', (req, res) => {
    res.sendFile(path.resolve(__dirname, '../railbuddy-client/dist', 'index.html'));
});

app.listen(port, () => {
    console.log(`RailBuddy backend listening on port ${port}`);
});
