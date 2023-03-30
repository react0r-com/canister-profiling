import Sha256 "mo:mrr/Sha256";
import Sha512 "mo:mrr/Sha512";
import Prng "mo:mrr/Prng";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Table "utils/table";
import Sha2 "mo:motoko-sha2";
import CryptoMo_SHA256 "mo:crypto.mo/SHA/SHA256";
import CryptoMo_SHA3_256 "mo:crypto.mo/SHA/SHA3_256";
import Hanbu_SHA3 "mo:motoko-sha3";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";

module {
  type RNG = { next : () -> ?Nat8; reset : () -> () };
  func random_iter(len_ : Nat) : RNG {
    object {
      let sfc = Prng.SFC64a();
      sfc.init();
      let len = len_;
      var i = 0;
      public func next() : ?Nat8 {
        i += 1;
        if (i <= len) {
          ?Nat8.fromIntWrap(Nat64.toNat(sfc.next()));
        } else null;
      };
      public func reset() {
        i := 0;
        sfc.init();
      };
    };
  };

  func ff_blocks_64(n : Nat) : Blob {
    let sfc = Prng.SFC64a();
    sfc.init();
    let len = if (n == 0) 0 else (64 * n - 9 : Nat);
    let arr = Array.tabulate<Nat8>(len, func(i) = Nat8.fromIntWrap(Nat64.toNat(sfc.next())));
    Blob.fromArray(arr);
  };

  func ff_blocks_128(n : Nat) : Blob {
    let sfc = Prng.SFC64a();
    sfc.init();
    let len = if (n == 0) 0 else (128 * n - 17 : Nat);
    let arr = Array.tabulate<Nat8>(len, func(i) = Nat8.fromIntWrap(Nat64.toNat(sfc.next())));
    Blob.fromArray(arr);
  };

  func Hanbu_SHA3_256_sum(val : [Nat8]) : [Nat8] {
    let sha3 = Hanbu_SHA3.Sha3(256);
    sha3.update(val);
    return sha3.finalize();
  };

  public func profile() {

    let lengths = [0, 1, 10, 100, 1000];
    let inputs_64 = Array.map<Nat, Blob>(lengths, ff_blocks_64);
    let inputs_128 = Array.map<Nat, Blob>(lengths, ff_blocks_128);

    let t = Table.Table(0, 6);
    var i = 0;
    while (i < lengths.size()) {
      t.stat_average_n(
        (debug_show lengths[i]) # " blocks",
        Nat.max(lengths[i], 1),
        [
          ?(func() = func() = ignore Sha256.fromBlob(#sha256, inputs_64[i])),
          ?(func() = func() = ignore Sha512.fromBlob(#sha512, inputs_128[i])),
          ?(func() = func() = ignore Sha2.fromBlob(#sha256, inputs_64[i])),
          ?(func() = func() = ignore CryptoMo_SHA256.sum(Blob.toArray(inputs_64[i]))),
          ?(func() = func() = ignore CryptoMo_SHA3_256.sum(Blob.toArray(inputs_64[i]))),
          ?(func() = func() = ignore Hanbu_SHA3_256_sum(Blob.toArray(inputs_64[i]))),
        ],
      );
      i += 1;
    };

    Debug.print(t.output(["Sha256",
                          "Sha512",
                          "Sha256-timohanke",
                          "Sha256-aviate-labs",
                          "Sha3_256-crypto-mo",
                          "Sha3_256-hanbu",
                         ]));
  };

  public func sha256_heap() : Any {
    let len : Nat = 64 * 1000 - 7;
    Sha256.fromIter(#sha256, random_iter(len));
  };
};
