var fs = require("fs");

fs.readFile("status-modules/wallet-raw.js", "utf8", function (err, data) {
    if (err) throw err;
    console.log();
    fs.writeFile("status-modules/wallet.js",
        ("module.exports=`" + data.replace(/[\\$'"]/g, "\\$&") + "`;"),
        function (err) {
            if (err) {
                return console.log(err);
            }
        });
});
