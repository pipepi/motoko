import Prim "mo:prim";
actor {
  Prim.debugPrint ("init'ed 0");
  stable var c = "a";
  var d = c; // unstable cached state
  public func inc() { d #= "a"; };
  public query func check(n : Int) : async () {
    Prim.debugPrint(d);
    assert (d.len() == n);
  };
  system func preupgrade(){
    Prim.debugPrint("preupgrade 0");
    c := d;
  };
  system func postupgrade(){
    Prim.debugPrint("postupgrade 0");
    d := c;
  };
}

