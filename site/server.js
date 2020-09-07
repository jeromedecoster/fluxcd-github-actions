const app = require('./app.js')

if (process.env.WEBSITE_PORT == null || process.env.WEBSITE_PORT.length == 0) { 
    throw new Error('WEBSITE_PORT environment variable is required')
}

app.listen(process.env.WEBSITE_PORT, () => { 
    console.log(`Listening on port ${process.env.WEBSITE_PORT}`) 
})