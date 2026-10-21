//----------------------------------------------------------------
//  ReleaseSignature.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Security.Cryptography;

namespace MGQOnline.Updates;

/// <summary>
/// Signs and checks release manifests with ECDSA on P-256 over SHA-256, as a DER sequence.
/// </summary>
public static class ReleaseSignature
{
    /// <summary>
    /// The object identifier of the P-256 curve (secp256r1).
    /// </summary>
    private const string P256Oid = "1.2.840.10045.3.1.7";

    /// <summary>
    /// The signature layout, the same that Node's crypto writes and reads by default.
    /// </summary>
    private const DSASignatureFormat Format = DSASignatureFormat.Rfc3279DerSequence;

    /// <summary>
    /// Signs a manifest's exact bytes.
    /// </summary>
    /// <param name="manifest">The manifest's bytes.</param>
    /// <param name="privateKeyPem">The P-256 private key in PEM.</param>
    /// <returns>The DER signature.</returns>
    /// <exception cref="UpdateRefusedException">The key is no P-256 private key.</exception>
    public static byte[] Sign(ReadOnlySpan<byte> manifest, string privateKeyPem)
    {
        using var key = ImportP256(privateKeyPem);
        return key.SignData(manifest, HashAlgorithmName.SHA256, Format);
    }

    /// <summary>
    /// Refuses a manifest unless the signature is a valid one of its exact bytes.
    /// </summary>
    /// <param name="manifest">The manifest's bytes.</param>
    /// <param name="signature">The DER signature; empty for an unsigned manifest.</param>
    /// <param name="publicKeyPem">The P-256 public key in PEM.</param>
    /// <exception cref="UpdateRefusedException">The manifest is unsigned or wrongly signed, or the key is no P-256 key.</exception>
    public static void Verify(ReadOnlySpan<byte> manifest, ReadOnlySpan<byte> signature, string publicKeyPem)
    {
        if (signature.IsEmpty)
        {
            throw new UpdateRefusedException("The release manifest is unsigned.");
        }

        using var key = ImportP256(publicKeyPem);

        if (!key.VerifyData(manifest, signature, HashAlgorithmName.SHA256, Format))
        {
            throw new UpdateRefusedException("The release manifest is wrongly signed.");
        }
    }

    /// <summary>
    /// Creates a new P-256 key pair, for tests and for setting up a signing key.
    /// </summary>
    /// <returns>The private key and the public key, each in PEM.</returns>
    public static (string PrivateKeyPem, string PublicKeyPem) CreateKeyPair()
    {
        using var key = ECDsa.Create(ECCurve.NamedCurves.nistP256);
        return (key.ExportPkcs8PrivateKeyPem(), key.ExportSubjectPublicKeyInfoPem());
    }

    /// <summary>
    /// Tells whether a curve is P-256, by its identifier or by one of its names.
    /// </summary>
    /// <param name="curve">The key's curve.</param>
    /// <returns>True for the named curve P-256.</returns>
    private static bool IsP256(ECCurve curve)
    {
        if (!curve.IsNamed)
        {
            return false;
        }

        var oid = curve.Oid;
        return string.Equals(oid.Value, P256Oid, StringComparison.Ordinal)
            || oid.FriendlyName is "nistP256" or "ECDSA_P256" or "secp256r1";
    }

    /// <summary>
    /// Reads a key and refuses any curve but P-256.
    /// </summary>
    /// <param name="pem">The key in PEM, private or public.</param>
    /// <returns>The key; the caller disposes it.</returns>
    /// <exception cref="UpdateRefusedException">The PEM holds no P-256 key.</exception>
    private static ECDsa ImportP256(string pem)
    {
        var key = ECDsa.Create();

        try
        {
            key.ImportFromPem(pem);

            if (!IsP256(key.ExportParameters(false).Curve))
            {
                throw new UpdateRefusedException("The release key is no P-256 key.");
            }

            return key;
        }
        catch (Exception ex) when (ex is ArgumentException or CryptographicException)
        {
            key.Dispose();
            throw new UpdateRefusedException("The release key is unreadable.", ex);
        }
        catch
        {
            key.Dispose();
            throw;
        }
    }
}
