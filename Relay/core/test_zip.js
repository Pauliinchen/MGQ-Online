//----------------------------------------------------------------
//  test_zip.js
//
//  Changelog:
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

// Makes the zips the tests feed the mod catalog, plain or deflated, with a header that may lie
// about a file's size.

/**
 * Makes a zip, its files plain or deflated.
 *
 * @param {Array<[string, string, boolean?, number?]>} entries Each file's name, text, whether to deflate it, and the unpacked size its headers claim when they are to lie.
 * @returns {Promise<Uint8Array>} The zip.
 */
export async function makeZip(entries) {
  const parts = [];
  const directory = [];
  let offset = 0;

  for (const [name, text, deflate, claimed] of entries) {
    const data = new TextEncoder().encode(text);
    const packed = deflate ? new Uint8Array(await new Response(new Blob([data]).stream().pipeThrough(new CompressionStream("deflate-raw"))).arrayBuffer()) : data;
    const nameBytes = new TextEncoder().encode(name);
    const size = claimed ?? data.length;
    const local = new DataView(new ArrayBuffer(30));
    local.setUint32(0, 0x04034b50, true);
    local.setUint16(8, deflate ? 8 : 0, true);
    local.setUint32(18, packed.length, true);
    local.setUint32(22, size, true);
    local.setUint16(26, nameBytes.length, true);
    const central = new DataView(new ArrayBuffer(46));
    central.setUint32(0, 0x02014b50, true);
    central.setUint16(10, deflate ? 8 : 0, true);
    central.setUint32(20, packed.length, true);
    central.setUint32(24, size, true);
    central.setUint16(28, nameBytes.length, true);
    central.setUint32(42, offset, true);
    parts.push(new Uint8Array(local.buffer), nameBytes, packed);
    directory.push(new Uint8Array(central.buffer), nameBytes);
    offset += 30 + nameBytes.length + packed.length;
  }

  const directorySize = directory.reduce((size, part) => size + part.length, 0);
  const end = new DataView(new ArrayBuffer(22));
  end.setUint32(0, 0x06054b50, true);
  end.setUint16(8, entries.length, true);
  end.setUint16(10, entries.length, true);
  end.setUint32(12, directorySize, true);
  end.setUint32(16, offset, true);
  const all = [...parts, ...directory, new Uint8Array(end.buffer)];
  const zip = new Uint8Array(all.reduce((size, part) => size + part.length, 0));
  let at = 0;

  for (const part of all) {
    zip.set(part, at);
    at += part.length;
  }

  return zip;
}

/**
 * Makes an upload as an admin's tool sends it: each file's path and hash, an empty line, then the zip.
 *
 * @param {Record<string, string>} files Each file's hash by its path inside Patch.
 * @param {Uint8Array} zip The zip.
 * @returns {Uint8Array} The upload.
 */
export function makeUpload(files, zip) {
  const list = new TextEncoder().encode(`${Object.entries(files).map(([path, hash]) => `${path}\t${hash}`).join("\n")}\n\n`);
  const upload = new Uint8Array(list.length + zip.length);
  upload.set(list, 0);
  upload.set(zip, list.length);
  return upload;
}
