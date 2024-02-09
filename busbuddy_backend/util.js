const fs = require("fs/promises");
const fileExists = async (filename) => {
    try {
        await fs.access(filename);
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