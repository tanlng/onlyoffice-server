/*
 * (c) Copyright Ascensio System SIA 2010-2024
 *
 * This program is a free software product. You can redistribute it and/or
 * modify it under the terms of the GNU Affero General Public License (AGPL)
 * version 3 as published by the Free Software Foundation. In accordance with
 * Section 7(a) of the GNU AGPL its Section 15 shall be amended to the effect
 * that Ascensio System SIA expressly excludes the warranty of non-infringement
 * of any third-party rights.
 *
 * This program is distributed WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR  PURPOSE. For
 * details, see the GNU AGPL at: http://www.gnu.org/licenses/agpl-3.0.html
 *
 * You can contact Ascensio System SIA at 20A-6 Ernesta Birznieka-Upish
 * street, Riga, Latvia, EU, LV-1050.
 *
 * The  interactive user interfaces in modified source and object code versions
 * of the Program must display Appropriate Legal Notices, as required under
 * Section 5 of the GNU AGPL version 3.
 *
 * Pursuant to Section 7(b) of the License you must retain the original Product
 * logo when distributing the program. Pursuant to Section 7(e) we decline to
 * grant you any rights under trademark law for use of our trademarks.
 *
 * All the Product's GUI elements, including illustrations and icon sets, as
 * well as technical writing content are licensed under the terms of the
 * Creative Commons Attribution-ShareAlike 4.0 International. See the License
 * terms at http://creativecommons.org/licenses/by-sa/4.0/legalcode
 *
 */

'use strict';

const config = require('config');
const utils = require('./utils');
const logger = require('./logger');
const constants = require('./constants');
const tenantManager = require('./tenantManager');
const runtimeConfigManager = require('./runtimeConfigManager');

function Context(){
  this.logger = logger.getLogger('nodeJS');
  this.initDefault();
}
Context.prototype.init = function(tenant, docId, userId, opt_shardKey, opt_WopiSrc) {
  this.setTenant(tenant);
  this.setDocId(docId);
  this.setUserId(userId);
  this.setShardKey(opt_shardKey);
  this.setWopiSrc(opt_WopiSrc);

  this.config = null;
  this.secret = null;
  this.license = null;
  //cache
  this.taskResultCache = null;
};
Context.prototype.initDefault = function() {
  this.init(tenantManager.getDefautTenant(), constants.DEFAULT_DOC_ID, constants.DEFAULT_USER_ID, undefined);
};
Context.prototype.initFromConnection = function(conn) {
  const tenant = tenantManager.getTenantByConnection(this, conn);
  let docId = conn.docid;
  if (!docId) {
    const handshake = conn.handshake;
    const docIdParsed = constants.DOC_ID_SOCKET_PATTERN.exec(handshake.url);
    if (docIdParsed && 1 < docIdParsed.length) {
      docId = docIdParsed[1];
    }
  }
  const userId = conn.user?.id;
  const shardKey = utils.getShardKeyByConnection(this, conn);
  const wopiSrc = utils.getWopiSrcByConnection(this, conn);
  this.init(tenant, docId || this.docId, userId || this.userId, shardKey, wopiSrc);
};
Context.prototype.initFromRequest = function(req) {
  const tenant = tenantManager.getTenantByRequest(this, req);
  const shardKey = utils.getShardKeyByRequest(this, req);
  const wopiSrc = utils.getWopiSrcByRequest(this, req);
  this.init(tenant, this.docId, this.userId, shardKey, wopiSrc);
};
Context.prototype.initFromTaskQueueData = function(task) {
  const ctx = task.getCtx();
  this.init(ctx.tenant, ctx.docId, ctx.userId, ctx.shardKey, ctx.wopiSrc);
};
Context.prototype.initFromPubSub = function(data) {
  const ctx = data.ctx;
  this.init(ctx.tenant, ctx.docId, ctx.userId, ctx.shardKey, ctx.wopiSrc);
};
Context.prototype.initTenantCache = async function() {
  const runtimeConfig = await runtimeConfigManager.getConfig(this);
  const tenantConfig = await tenantManager.getTenantConfig(this);
  this.config = utils.deepMergeObjects({}, runtimeConfig, tenantConfig);

  //todo license and secret
};

Context.prototype.setTenant = function(tenant) {
  this.tenant = tenant;
  this.logger.addContext('TENANT', tenant);
};
Context.prototype.setDocId = function(docId) {
  this.docId = docId;
  this.logger.addContext('DOCID', docId);
};
Context.prototype.setUserId = function(userId) {
  this.userId = userId;
  this.logger.addContext('USERID', userId);
};
Context.prototype.setShardKey = function(shardKey) {
  this.shardKey = shardKey;
};
Context.prototype.setWopiSrc = function(wopiSrc) {
  this.wopiSrc = wopiSrc;
};
Context.prototype.toJSON = function() {
  return {
    tenant: this.tenant,
    docId: this.docId,
    userId: this.userId,
    shardKey: this.shardKey,
    wopiSrc: this.wopiSrc
  }
};
Context.prototype.getCfg = function(property, defaultValue) {
  if (this.config){
    return getImpl(this.config, property) ?? defaultValue;
  }
  return defaultValue;
};
/**
 * Get the full configuration by combining system config with context config
 * @returns {object} The merged configuration object
 */
Context.prototype.getFullCfg = function() {
  return utils.deepMergeObjects(config.util.toObject(), this.config);
};

/**
 * Underlying get mechanism
 *
 * @private
 * @method getImpl
 * @param object {object} - Object to get the property for
 * @param property {string | array[string]} - The property name to get (as an array or '.' delimited string)
 * @return value {*} - Property value, including undefined if not defined.
 */
function getImpl(object, property) {
  //from https://github.com/node-config/node-config/blob/a8b91ac86b499d11b90974a2c9915ce31266044a/lib/config.js#L137
  var elems = Array.isArray(property) ? property : property.split('.'),
    name = elems[0],
    value = object[name];
  if (elems.length <= 1) {
    return value;
  }
  // Note that typeof null === 'object'
  if (value === null || typeof value !== 'object') {
    return undefined;
  }
  return getImpl(value, elems.slice(1));
};

exports.Context = Context;
exports.global = new Context();
