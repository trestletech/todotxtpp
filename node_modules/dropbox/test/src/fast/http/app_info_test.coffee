describe 'Dropbox.Http.AppInfo', ->
  describe '.parse', ->
    describe 'on a datastores app', ->
      beforeEach ->
        appInfo = {
          "name": "Datastores sample app",
          "icons": {
            "64x64": "https://photos-1.dropbox.com/pi/64x64/OkMXX6d3pl00VrcKu6p-hfjS5wvz9I1j4Nn2sZDFsVs/0/1376456400/7482db5/"
          },
          "permissions": {
            "datastores": true
          }
        }
        @appInfo = Dropbox.Http.AppInfo.parse appInfo, 'qre1rsgf4iszxcu'

      it 'parses name correctly', ->
        expect(@appInfo).to.have.property 'name'
        expect(@appInfo.name).to.equal 'Datastores sample app'

      it 'parses canUseDatastores correctly', ->
        expect(@appInfo).to.have.property 'canUseDatastores'
        expect(@appInfo.canUseDatastores).to.equal true

      it 'parses canUseFiles correctly', ->
        expect(@appInfo).to.have.property 'canUseFiles'
        expect(@appInfo.canUseFiles).to.equal false

      it 'parses canUseFullDropbox correctly', ->
        expect(@appInfo).to.have.property 'canUseFullDropbox'
        expect(@appInfo.canUseFullDropbox).to.equal false

      it 'parses hasAppFolder correctly', ->
        expect(@appInfo).to.have.property 'hasAppFolder'
        expect(@appInfo.hasAppFolder).to.equal false

      describe '#icon', ->
        it 'returns the small icon correctly', ->
          expect(@appInfo.icon(Dropbox.Http.AppInfo.ICON_SMALL)).to.equal(
             'https://photos-1.dropbox.com/pi/64x64/OkMXX6d3pl00VrcKu6p-hfjS5wvz9I1j4Nn2sZDFsVs/0/1376456400/7482db5/')

        it 'returns the lack of a large icon correctly', ->
          expect(@appInfo.icon(Dropbox.Http.AppInfo.ICON_LARGE)).to.equal null

        it 'interprets height correctly', ->
          expect(@appInfo.icon(Dropbox.Http.AppInfo.ICON_SMALL,
                               Dropbox.Http.AppInfo.ICON_SMALL)).to.equal(
             'https://photos-1.dropbox.com/pi/64x64/OkMXX6d3pl00VrcKu6p-hfjS5wvz9I1j4Nn2sZDFsVs/0/1376456400/7482db5/')

          expect(@appInfo.icon(Dropbox.Http.AppInfo.ICON_SMALL,
                               Dropbox.Http.AppInfo.ICON_LARGE)).to.equal null

    describe 'on an app folder app', ->
      beforeEach ->
        appInfo = {
          "name": "Automated Testing Keys",
          "icons": {
            "64x64": "https://photos-1.dropbox.com/pi/64x64/KXc4DqzIbFpIAPel2rvJv1yNSAVRVTjACYKynaM2K_g/0/1376524800/4ead4f2/",
            "256x256": "https://photos-4.dropbox.com/pi/256x256/EphMShFe8Orja4WRPlkUnBZNABs-V2WbhkZZlAnVFe0/0/1376524800/fb0e049/"
          },
          "permissions": {
            "datastores": true,
            "files": "app_folder"
          }
        }
        @appInfo = Dropbox.Http.AppInfo.parse appInfo, 'qre1rsgf4iszxcu'

      it 'parses name correctly', ->
        expect(@appInfo).to.have.property 'name'
        expect(@appInfo.name).to.equal 'Automated Testing Keys'

      it 'parses canUseDatastores correctly', ->
        expect(@appInfo).to.have.property 'canUseDatastores'
        expect(@appInfo.canUseDatastores).to.equal true

      it 'parses canUseFiles correctly', ->
        expect(@appInfo).to.have.property 'canUseFiles'
        expect(@appInfo.canUseFiles).to.equal true

      it 'parses canUseFullDropbox correctly', ->
        expect(@appInfo).to.have.property 'canUseFullDropbox'
        expect(@appInfo.canUseFullDropbox).to.equal false

      it 'parses hasAppFolder correctly', ->
        expect(@appInfo).to.have.property 'hasAppFolder'
        expect(@appInfo.hasAppFolder).to.equal true

      describe '#icon', ->
        it 'returns the small icon correctly', ->
          expect(@appInfo.icon(Dropbox.Http.AppInfo.ICON_SMALL)).to.equal(
             'https://photos-1.dropbox.com/pi/64x64/KXc4DqzIbFpIAPel2rvJv1yNSAVRVTjACYKynaM2K_g/0/1376524800/4ead4f2/')

        it 'returns the large icon correctly', ->
          expect(@appInfo.icon(Dropbox.Http.AppInfo.ICON_LARGE)).to.equal(
             'https://photos-4.dropbox.com/pi/256x256/EphMShFe8Orja4WRPlkUnBZNABs-V2WbhkZZlAnVFe0/0/1376524800/fb0e049/')

    describe 'on a full Dropbox app', ->
      beforeEach ->
        appInfo = {
          "name": "Automated Testing Keys (Full Access)",
          "icons": {
            "64x64": "https://photos-1.dropbox.com/pi/64x64/KXc4DqzIbFpIAPel2rvJv1yNSAVRVTjACYKynaM2K_g/0/1376524800/4ead4f2/",
            "256x256": "https://photos-4.dropbox.com/pi/256x256/EphMShFe8Orja4WRPlkUnBZNABs-V2WbhkZZlAnVFe0/0/1376524800/fb0e049/"
          },
          "permissions": {
            "datastores": true,
            "files": "full_dropbox"
          }
        }
        @appInfo = Dropbox.Http.AppInfo.parse appInfo, 'qre1rsgf4iszxcu'

      it 'parses name correctly', ->
        expect(@appInfo).to.have.property 'name'
        expect(@appInfo.name).to.equal 'Automated Testing Keys (Full Access)'

      it 'parses canUseDatastores correctly', ->
        expect(@appInfo).to.have.property 'canUseDatastores'
        expect(@appInfo.canUseDatastores).to.equal true

      it 'parses canUseFiles correctly', ->
        expect(@appInfo).to.have.property 'canUseFiles'
        expect(@appInfo.canUseFiles).to.equal true

      it 'parses canUseFullDropbox correctly', ->
        expect(@appInfo).to.have.property 'canUseFullDropbox'
        expect(@appInfo.canUseFullDropbox).to.equal true

      it 'parses hasAppFolder correctly', ->
        expect(@appInfo).to.have.property 'hasAppFolder'
        expect(@appInfo.hasAppFolder).to.equal false
