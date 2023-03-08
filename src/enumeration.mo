import E "mo:base/ExperimentalInternetComputer";
import Debug "mo:base/Debug";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import RBTree "mo:base/RBTree";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Order "mo:base/Order";
import Prim "mo:⛔";
import Vector "mo:mrr/Vector";
import Enumeration "mo:mrr/Enumeration";
import Float "mo:base/Float";
import Int "mo:base/Int";

actor {
  class RNG() {
    var seed = 234234;

    public func next() : Nat {
      seed += 1;
      let a = seed * 15485863;
      a * a * a % 2038074743;
    };

    public func blob() : Blob {
      let a = Array.tabulate<Nat8>(29, func(i) = Nat8.fromNat(next() % 256));
      Blob.fromArray(a);
    };

    public func with_byte(byte : Nat8) : Blob {
      let a = Array.tabulate<Nat8>(29, func(i) = byte);
      Blob.fromArray(a);
    };
  };

  func toRBTree(t : Enumeration.Tree, a : [var Blob]) : Tree {
    switch (t) {
      case (#red(left, key, right)) #node(#R, toRBTree(left, a), (a[key], ?key), toRBTree(right, a));
      case (#black(left, key, right)) #node(#B, toRBTree(left, a), (a[key], ?key), toRBTree(right, a));
      case (#leaf) #leaf;
    };
  };

  func root(t : Tree) : Blob {
    switch (t) {
      case (#node(_, _, key, _)) key.0;
      case (#leaf) Prim.trap("ff");
    };
  };

  func leftmost(t : Tree) : Blob {
    switch (t) {
      case (#node(_, #leaf, key, _)) key.0;
      case (#node(_, left, _, _)) leftmost(left);
      case (#leaf) Prim.trap("");
    };
  };

  func rightmost(t : Tree) : Blob {
    switch (t) {
      case (#node(_, _, key, #leaf)) key.0;
      case (#node(_, _, _, right)) rightmost(right);
      case (#leaf) Prim.trap("");
    };
  };

  func max_leaf(t : Tree) : (Nat, Blob) {
    switch (t) {
      case (#node(_, #leaf, key, #leaf)) {
        (1, key.0);
      };
      case (#node(_, left, key, #leaf)) {
        let (x, y) = max_leaf(left);
        (x + 1, y);
      };
      case (#node(_, #leaf, key, right)) {
        let (x, y) = max_leaf(right);
        (x + 1, y);
      };
      case (#node(_, left, _, right)) {
        let a = max_leaf(left);
        let b = max_leaf(right);
        if (a.0 > b.0) { (a.0 + 1, a.1) } else { (b.0 + 1, b.1) };
      };
      case (#leaf) Prim.trap("");
    };
  };

  func min_leaf(t : Tree) : (Nat, Blob) {
    switch (t) {
      case (#node(_, #leaf, key, #leaf)) {
        (1, key.0);
      };
      case (#node(_, left, key, #leaf)) {
        let (x, y) = min_leaf(left);
        (x + 1, y);
      };
      case (#node(_, #leaf, key, right)) {
        let (x, y) = min_leaf(right);
        (x + 1, y);
      };
      case (#node(_, left, _, right)) {
        let a = min_leaf(left);
        let b = min_leaf(right);
        if (a.0 < b.0) { (a.0 + 1, a.1) } else { (b.0 + 1, b.1) };
      };
      case (#leaf) Prim.trap("");
    };
  };

  func memory(f : () -> ()) : Nat {
    let before = Prim.rts_heap_size();
    f();
    let after = Prim.rts_heap_size();
    after - before;
  };

  let n = 2 ** 12;
  let m = 2 ** 6;
  type Tree = RBTree.Tree<Blob, Nat>;

  public shared func profile() : async () {
    let stats = Buffer.Buffer<(Text, Nat, Nat)>(0);
    let r = RNG();
    var blobs = Array.tabulate<Blob>(n, func(i) = r.blob());
    let enumertion = Enumeration.Enumeration();
    let rb = RBTree.RBTree<Blob, Nat>(Blob.compare);

    func average(blobs : [Blob], get : (Blob) -> ()) : Nat {
      var i = 0;
      var sum = 0;
      while (i < blobs.size()) {
        sum += Nat64.toNat(E.countInstructions(func() = get(blobs[i])));
        i += 1;
      };
      Int.abs(Float.toInt(Float.fromInt(sum) / Float.fromInt(blobs.size())));
    };

    func stat(method : Text, enum_key : Blob, rb_key : Blob) {
      stats.add((
        method,
        Nat64.toNat(E.countInstructions(func() = ignore enumertion.lookup(enum_key))),
        Nat64.toNat(E.countInstructions(func() = ignore rb.get(rb_key))),
      ));
    };

    let mem = (
      memory(
        func() {
          var i = 0;
          while (i < n) {
            ignore enumertion.add(blobs[i]);
            i += 1;
          };
        },
      ),
      memory(
        func() {
          var i = 0;
          while (i < n) {
            rb.put(blobs[i], i);
            i += 1;
          };
        },
      ),
    );

    let random = Array.tabulate<Blob>(m, func(i) = blobs[i * m]);
    stats.add((
      "random blobs inside average",
      average(random, func(b) = ignore enumertion.lookup(b)),
      average(random, func(b) = ignore rb.get(b)),
    ));

    let others = Array.tabulate<Blob>(m, func(i) = r.blob());
    stats.add((
      "random blobs average",
      average(others, func(b) = ignore enumertion.lookup(b)),
      average(others, func(b) = ignore rb.get(b)),
    ));

    let (t, a, _) = enumertion.share();
    let enumertion_tree = toRBTree(t, a);
    let rb_tree = rb.share();

    stat("root", root(enumertion_tree), root(rb_tree));

    stat("leftmost", leftmost(enumertion_tree), leftmost(rb_tree));
    stat("rightmost", rightmost(enumertion_tree), rightmost(rb_tree));

    stat("min blob", r.with_byte(0), r.with_byte(0));
    stat("max blob", r.with_byte(255), r.with_byte(255));

    stat("min leaf", min_leaf(enumertion_tree).1, min_leaf(rb_tree).1);
    stat("max leaf", max_leaf(enumertion_tree).1, max_leaf(rb_tree).1);

    var result = "\nTesting for n = " # Nat.toText(n) # "\n\n";
    result #= "Memory usage of Enumeration: " # Nat.toText(mem.0) # "\n\n";
    result #= "Memory usage of RBTree: " # Nat.toText(mem.1) # "\n\n";
    result #= "|method|enumeration|red-black tree|\n|---|---|---|\n";
    for ((method, enumertion, rb) in stats.vals()) {
      result #= "|" # method # "|" # Nat.toText(enumertion) # "|" # Nat.toText(rb) # "|\n";
    };

    result #= "\n";

    result #= "min leaf in enumeration: " # Nat.toText(min_leaf(enumertion_tree).0) # "\n\n";
    result #= "min leaf in red-black tree: " # Nat.toText(min_leaf(rb_tree).0) # "\n\n";
    result #= "max leaf in enumeration: " # Nat.toText(max_leaf(enumertion_tree).0) # "\n\n";
    result #= "max leaf in red-black tree: " # Nat.toText(max_leaf(rb_tree).0) # "\n\n";

    Debug.print(result);
  };
};
