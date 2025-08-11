'use strict';
const fs = require('fs');
const path = require('path');
const { BlobServiceClient, StorageSharedKeyCredential, generateBlobSASQueryParameters, BlobSASPermissions } = require('@azure/storage-blob');
const mime = require('mime');
const config = require('config');
const utils = require('../utils');
const ms = require('ms');
const commonDefines = require('../commondefines');

const cfgExpSessionAbsolute = ms(config.get('services.CoAuthoring.expire.sessionabsolute'));
const cfgCacheStorage = config.get('storage');
const MAX_DELETE_OBJECTS = 1000;
const blobServiceClients = {};

/**
 * Gets or creates a BlobServiceClient for the given storage configuration.
 *
 * @param {Object} storageCfg - configuration object from default.json
 * @returns {BlobServiceClient} The Azure Blob Service client
 */
function getBlobServiceClient(storageCfg) {
  const configKey = `${storageCfg.accessKeyId}_${storageCfg.bucketName}`;
  if (!blobServiceClients[configKey]) {
    const credential = new StorageSharedKeyCredential(
      storageCfg.accessKeyId,
      storageCfg.secretAccessKey
    );
    if (storageCfg.endpoint.includes(storageCfg.accessKeyId)) {
      blobServiceClients[configKey] = new BlobServiceClient(storageCfg.endpoint, credential);
    } else {
      const endpointUrl = new URL(storageCfg.endpoint.replace(/\/+$/, ''));
      blobServiceClients[configKey] = new BlobServiceClient(
        `${endpointUrl.protocol}//${storageCfg.accessKeyId}.${endpointUrl.host}`,
        credential);
    }
  }
  return blobServiceClients[configKey];
}

/**
 * Gets a ContainerClient for the specified storage configuration.
 *
 * @param {Object} storageCfg - configuration object from default.json
 * @returns {ContainerClient} The Azure Container client
 */
function getContainerClient(storageCfg) {
  const blobServiceClient = getBlobServiceClient(storageCfg);
  return blobServiceClient.getContainerClient(storageCfg.bucketName);
}

/**
 * Gets a BlockBlobClient for the specified storage configuration and blob name.
 *
 * @param {Object} storageCfg - configuration object from default.json
 * @param {string} blobName - The name of the blob
 * @returns {BlockBlobClient} The Azure Block Blob client
 */
function getBlobClient(storageCfg, blobName) {
  const containerClient = getContainerClient(storageCfg);
  return containerClient.getBlockBlobClient(blobName);
}

/**
 * Constructs a full file path by combining the storage folder name and the path.
 *
 * @param {Object} storageCfg - configuration object from default.json
 * @param {string} strPath - The relative path of the file
 * @returns {string} The full file path
 */
function getFilePath(storageCfg, strPath) {
  const storageFolderName = storageCfg.storageFolderName;
  return `${storageFolderName}/${strPath}`;
}

/**
 * @param {Object} baseOptions - Base options object
 * @param {Object} storageCfg - Storage configuration
 * @param {string} commandType - uploadData, uploadStream, download, etc.
 * @returns {Object|undefined} Merged options or undefined if empty
 */
function applyCommandOptions(baseOptions, storageCfg, commandType) {
  if (storageCfg.commandOptions.az && storageCfg.commandOptions.az[commandType]) {
    const configOptions = storageCfg.commandOptions.az[commandType];
    if (configOptions && Object.keys(configOptions).length > 0) {
      return {...baseOptions, ...configOptions};
    }
  }
  return Object.keys(baseOptions).length > 0 ? baseOptions : undefined;
}

async function listObjectsExec(storageCfg, prefix, output = []) {
  const containerClient = getContainerClient(storageCfg);
  const storageFolderName = storageCfg.storageFolderName;
  const prefixWithFolder = storageFolderName ? `${storageFolderName}/${prefix}` : prefix;

  const baseOptions = {prefix: prefixWithFolder};
  const listOptions = applyCommandOptions(baseOptions, storageCfg, 'listBlobsFlat');

  for await (const blob of containerClient.listBlobsFlat(listOptions)) {
    const relativePath = storageFolderName ?
      blob.name.substring(storageFolderName.length + 1) : blob.name;
    output.push(relativePath);
  }
  return output;
}

async function deleteObjectsHelp(storageCfg, aKeys) {
  const containerClient = getContainerClient(storageCfg);
  const deleteOptions = applyCommandOptions({}, storageCfg, 'deleteBlob');
  await Promise.all(
    aKeys.map(key => {
      return containerClient.deleteBlob(key.Key, deleteOptions);
    })
  );
}

async function headObject(storageCfg, strPath) {
  const blobClient = getBlobClient(storageCfg, getFilePath(storageCfg, strPath));
  const properties = await blobClient.getProperties();
  return {ContentLength: properties.contentLength};
}

async function getObject(storageCfg, strPath) {
  const blobClient = getBlobClient(storageCfg, getFilePath(storageCfg, strPath));
  const options = applyCommandOptions({}, storageCfg, 'download');
  const response = await blobClient.download(options);
  return await utils.stream2Buffer(response.readableStreamBody);
}

async function createReadStream(storageCfg, strPath) {
  const blobClient = getBlobClient(storageCfg, getFilePath(storageCfg, strPath));
  const options = applyCommandOptions({}, storageCfg, 'download');
  const response = await blobClient.download(options);
  return {
    contentLength: response.contentLength,
    readStream: response.readableStreamBody
  };
}

async function putObject(storageCfg, strPath, buffer, contentLength) {
  const blobClient = getBlobClient(storageCfg, getFilePath(storageCfg, strPath));

  const baseOptions = {
    blobHTTPHeaders: {
      contentType: mime.getType(strPath),
      contentDisposition: utils.getContentDisposition(path.basename(strPath))
    }
  };
  const uploadOptions = applyCommandOptions(baseOptions, storageCfg, 'uploadData');
  
  if (buffer instanceof Buffer) {
    await blobClient.uploadData(buffer, uploadOptions);
  } else if (typeof buffer.pipe === 'function') {
    await blobClient.uploadStream(buffer, undefined, undefined, uploadOptions);
  } else {
    throw new TypeError('Input must be Buffer or Readable stream');
  }
}

async function uploadObject(storageCfg, strPath, filePath) {
  const blockBlobClient = getBlobClient(storageCfg, getFilePath(storageCfg, strPath));
  const uploadStream = fs.createReadStream(filePath);

  const uploadOptions = {
    blobHTTPHeaders: {
      contentType: mime.getType(strPath),
      contentDisposition: utils.getContentDisposition(path.basename(strPath))
    }
  };
  const finalOptions = applyCommandOptions(uploadOptions, storageCfg, 'uploadStream');

  await blockBlobClient.uploadStream(
    uploadStream,
    undefined,
    undefined,
    finalOptions
  );
}

async function copyObject(storageCfgSrc, storageCfgDst, sourceKey, destinationKey) {
  const sourceBlobClient = getBlobClient(storageCfgSrc, getFilePath(storageCfgSrc, sourceKey));
  const destBlobClient = getBlobClient(storageCfgDst, getFilePath(storageCfgDst, destinationKey));
  const sasToken = generateBlobSASQueryParameters({
    containerName: storageCfgSrc.bucketName,
    blobName: getFilePath(storageCfgSrc, sourceKey),
    permissions: BlobSASPermissions.parse("r"),
    startsOn: new Date(),
    expiresOn: new Date(Date.now() + 3600 * 1000)
  }, new StorageSharedKeyCredential(storageCfgSrc.accessKeyId, storageCfgSrc.secretAccessKey)).toString();

  const copyOptions = applyCommandOptions({}, storageCfgDst, 'syncCopyFromURL');
  await destBlobClient.syncCopyFromURL(`${sourceBlobClient.url}?${sasToken}`, copyOptions);
}

async function listObjects(storageCfg, strPath) {
  return await listObjectsExec(storageCfg, strPath);
}

async function deleteObject(storageCfg, strPath) {
  const blobClient = getBlobClient(storageCfg, getFilePath(storageCfg, strPath));
  const options = applyCommandOptions({}, storageCfg, 'deleteBlob');
  await blobClient.delete(options);
}

async function deleteObjects(storageCfg, strPaths) {
  let aKeys = strPaths.map(path => ({Key: getFilePath(storageCfg, path)}));
  for (let i = 0; i < aKeys.length; i += MAX_DELETE_OBJECTS) {
    await deleteObjectsHelp(storageCfg, aKeys.slice(i, i + MAX_DELETE_OBJECTS));
  }
}

async function deletePath(storageCfg, strPath) {
  let list = await listObjects(storageCfg, strPath);
  await deleteObjects(storageCfg, list);
}

async function getDirectSignedUrl(ctx, storageCfg, baseUrl, strPath, urlType, optFilename, opt_creationDate) {
  const storageUrlExpires = storageCfg.fs.urlExpires;
  let expires = (commonDefines.c_oAscUrlTypes.Session === urlType ? cfgExpSessionAbsolute / 1000 : storageUrlExpires) || 31536000;
  expires = Math.min(expires, 604800);

  const userFriendlyName = optFilename ? optFilename.replace(/\//g, "%2f") : path.basename(strPath);
  const contentDisposition = utils.getContentDisposition(userFriendlyName, null, null);

  const blobClient = getBlobClient(storageCfg, getFilePath(storageCfg, strPath));

  const sasOptions = {
    permissions: BlobSASPermissions.parse("r"),
    expiresOn: new Date(Date.now() + expires * 1000),
    contentDisposition,
    contentType: mime.getType(strPath)
  };

  return await blobClient.generateSasUrl(sasOptions);
}

function needServeStatic() {
  return !cfgCacheStorage.useDirectStorageUrls;
}

module.exports = {
  headObject,
  getObject,
  createReadStream,
  putObject,
  uploadObject,
  copyObject,
  listObjects,
  deleteObject,
  deletePath,
  getDirectSignedUrl,
  needServeStatic
};
