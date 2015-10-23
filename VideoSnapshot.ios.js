/**
 * @providesModule VideoSnapshot
 * @flow
 */
'use strict';

var NativeVideoSnapshot = require('NativeModules').VideoSnapshot;

/**
 * High-level docs for the VideoSnapshot iOS API can be written here.
 */

var VideoSnapshot = {
  snapshot: function(options, cb) {
    NativeVideoSnapshot.snapshot(cb, options);
  }
};

module.exports = VideoSnapshot;
