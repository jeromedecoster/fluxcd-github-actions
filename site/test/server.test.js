const expect = require('chai').expect

var port

describe('server.js', function () {

    beforeEach(function () {
        port = process.env.WEBSITE_PORT
    })

    afterEach(function () {
        process.env.WEBSITE_PORT = port
    })

    it('variable WEBSITE_PORT must be defined', function (done) {
        try {
            delete process.env.WEBSITE_PORT
            require('../server.js')
        } catch (err) {
            expect(process.env.WEBSITE_PORT).to.be.undefined
            expect(err.message).to.include('WEBSITE_PORT')
            expect(err.message).to.include('required')
            done()
        }
    })

    it('variable WEBSITE_PORT cannot be blank', function (done) {
        try {
            process.env.WEBSITE_PORT = ''
            require('../server.js')
        } catch (err) {
            expect(err.message).to.include('WEBSITE_PORT')
            expect(err.message).to.include('required')
            done()
        }
    })
})