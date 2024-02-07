const bcrypt = require('bcryptjs');
const bcryptSaltRounds = 12;
const dotenv = require('dotenv');
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

dbclient.query(
    `select * from bus_staff`
).then(async qres2 => {
    //console.log(qres2.rows[0].start_location);
    qres2.rows.forEach(td => {
        console.log(td.password);
        let হেছ = bcrypt.hashSync(td.password, bcryptSaltRounds);
        console.log(হেছ);
        dbclient.query(
            `update bus_staff set password=$1 where id=$2`,
            [হেছ, td.id]
        ).then(async qres3 => {
            //console.log(qres2.rows[0].start_location);
            console.log(qres3);
        }).catch(e => console.error(e.stack));
    });
}).catch(e => console.error(e.stack));
