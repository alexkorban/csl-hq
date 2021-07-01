express = require("express")
require("express-namespace")
routes = require("./routes")
http = require "http"
path = require "path"

app = express()

# All environments
app.set("port", process.env.PORT || 5000)
app.set("views", path.join(__dirname, 'views'))
app.set("view engine", "ejs")
app.use(express.favicon())
app.use(express.logger("dev"))
app.use(express.json())
app.use(express.urlencoded())
app.use(express.methodOverride())
app.use(app.router)
app.use(express.static(path.join(__dirname, "public")))

# Development only
if process.env.NODE_ENV == "dev"
    app.use(express.errorHandler())

app.all "*", (req, res, next) =>
    if process.env.NODE_ENV == "dev" || req.headers["x-forwarded-proto"] == "https"
        next()
    else
        res.redirect "https://" + req.headers.host + req.url


app.get("/", routes.index)


http.createServer(app).listen app.get("port"), ->
    console.log("Express server listening on port " + app.get("port"))
