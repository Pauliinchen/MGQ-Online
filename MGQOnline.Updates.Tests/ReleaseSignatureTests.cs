//----------------------------------------------------------------
//  ReleaseSignatureTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Security.Cryptography;
using MGQOnline.Updates.Tests.Support;

namespace MGQOnline.Updates.Tests;

/// <summary>
/// Tests signing and checking manifests.
/// </summary>
public sealed class ReleaseSignatureTests
{
    /// <summary>
    /// The contract's manifest bytes, signed by the tests' key.
    /// </summary>
    private static readonly byte[] Manifest = TestReleases.Fixture("manifest.json");

    /// <summary>
    /// A signature of the exact bytes with the matching key passes.
    /// </summary>
    [Fact]
    public void AcceptsAGoodSignature()
    {
        var signature = ReleaseSignature.Sign(Manifest, TestReleases.Keys.PrivateKeyPem);

        ReleaseSignature.Verify(Manifest, signature, TestReleases.Keys.PublicKeyPem);
    }

    /// <summary>
    /// The signature is a DER sequence, the layout Node reads by default.
    /// </summary>
    [Fact]
    public void SignsAsADerSequence()
    {
        var signature = ReleaseSignature.Sign(Manifest, TestReleases.Keys.PrivateKeyPem);

        Assert.Equal(0x30, signature[0]);
        Assert.Equal(signature.Length - 2, signature[1]);
    }

    /// <summary>
    /// An unsigned manifest is refused.
    /// </summary>
    [Fact]
    public void RefusesAnUnsignedManifest()
    {
        var refusal = Assert.Throws<UpdateRefusedException>(
            () => ReleaseSignature.Verify(Manifest, [], TestReleases.Keys.PublicKeyPem));

        Assert.Contains("unsigned", refusal.Message, StringComparison.Ordinal);
    }

    /// <summary>
    /// A manifest changed after signing is refused.
    /// </summary>
    [Fact]
    public void RefusesAChangedManifest()
    {
        var signature = ReleaseSignature.Sign(Manifest, TestReleases.Keys.PrivateKeyPem);
        var changed = (byte[])Manifest.Clone();
        changed[^3] ^= 1;

        Assert.Throws<UpdateRefusedException>(
            () => ReleaseSignature.Verify(changed, signature, TestReleases.Keys.PublicKeyPem));
    }

    /// <summary>
    /// A signature by another key is refused.
    /// </summary>
    [Fact]
    public void RefusesAnotherKeysSignature()
    {
        var other = ReleaseSignature.CreateKeyPair();
        var signature = ReleaseSignature.Sign(Manifest, other.PrivateKeyPem);

        Assert.Throws<UpdateRefusedException>(
            () => ReleaseSignature.Verify(Manifest, signature, TestReleases.Keys.PublicKeyPem));
    }

    /// <summary>
    /// A signature in the IEEE P1363 layout and random bytes are refused.
    /// </summary>
    [Fact]
    public void RefusesOtherSignatureLayouts()
    {
        using var key = ECDsa.Create();
        key.ImportFromPem(TestReleases.Keys.PrivateKeyPem);
        var p1363 = key.SignData(Manifest, HashAlgorithmName.SHA256, DSASignatureFormat.IeeeP1363FixedFieldConcatenation);

        Assert.Throws<UpdateRefusedException>(
            () => ReleaseSignature.Verify(Manifest, p1363, TestReleases.Keys.PublicKeyPem));
        Assert.Throws<UpdateRefusedException>(
            () => ReleaseSignature.Verify(Manifest, RandomNumberGenerator.GetBytes(70), TestReleases.Keys.PublicKeyPem));
    }

    /// <summary>
    /// A key on another curve is refused, both for signing and for checking.
    /// </summary>
    [Fact]
    public void RefusesOtherCurves()
    {
        using var p384 = ECDsa.Create(ECCurve.NamedCurves.nistP384);
        var signature = p384.SignData(Manifest, HashAlgorithmName.SHA256, DSASignatureFormat.Rfc3279DerSequence);

        Assert.Throws<UpdateRefusedException>(
            () => ReleaseSignature.Verify(Manifest, signature, p384.ExportSubjectPublicKeyInfoPem()));
        Assert.Throws<UpdateRefusedException>(
            () => ReleaseSignature.Sign(Manifest, p384.ExportPkcs8PrivateKeyPem()));
    }

    /// <summary>
    /// Text that is no key is refused.
    /// </summary>
    [Fact]
    public void RefusesNonKeys()
    {
        var signature = ReleaseSignature.Sign(Manifest, TestReleases.Keys.PrivateKeyPem);

        Assert.Throws<UpdateRefusedException>(() => ReleaseSignature.Verify(Manifest, signature, "no key"));
    }
}
