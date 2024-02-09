const fs = require("fs");
const fileExists = async (filename) => {
    try {
        await access(filename);
        return true;
    } catch (err) {
        if (err.code === 'ENOENT') {
            return false;
        } else {
            throw err;
        };
    };
};

module.exports = { fileExists };