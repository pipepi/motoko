open Syntax
open Source
open Types
open Typing
open Printf

(*TBR*)

type value =
    | NullV 
    | BoolV of bool
    | NatV of Natural.t
    | IntV of Integer.t
    | Word8V of Word8.t
    | Word16V of Word16.t
    | Word32V of Word32.t
    | Word64V of Word64.t
    | FloatV of Float.t
    | CharV of unicode
    | TextV of string
    | TupV of value list
    | ObjV of value Env.t
    | ArrV of value array
    | OptV of value option (* TBR *)
    | FuncV of (value -> cont -> value)
    | VarV of value ref
    | RecV of recursive
    | AsyncV of async

and async = {mutable result: value option; mutable waiters : cont list}
and recursive = {mutable definition: value option}
and cont = value -> value

let nullV = NullV
let null_of_V (NullV) = ()
let boolV b = BoolV b
let bool_of_V (BoolV b) = b
let natV n = NatV n
let nat_of_V (NatV n) = n
let intV n = IntV n
let int_of_V (IntV n) = n
let word8V w = Word8V w
let word8_of_V (Word8V w) = w
let word16V w = Word16V w
let word16_of_V (Word16V w) = w
let word32V w = Word32V w
let word32_of_V (Word32V w) = w
let word64V w = Word64V w
let word64_of_V (Word64V w) = w

let floatV f = FloatV f
let float_of_V (FloatV f) = f
let charV c = CharV c
let char_of_V (CharV c) = c
let textV s = TextV s
let text_of_V (TextV s) = s
let arrV a = ArrV a
let arr_of_V (ArrV a) = a
let tupV vs = TupV vs
let tup_of_V (TupV vs) = vs
let objV ve = ObjV ve
let obj_of_V (ObjV ve) = ve
let optV ve = OptV ve
let opt_of_V (OptV v) = v
let funcV f = FuncV f
let func_of_V (FuncV f) = f
let unitV = TupV([])
let asyncV async = AsyncV async
let recV d = RecV {definition=d} 
let rec_of_V (RecV r) = r

let projV (TupV vs) n = List.nth vs (Int32.to_int n)
let dotV (ObjV ve) v = Env.find v ve
let checkV v =
     match v with
     | RecV r ->
        (match r.definition with
         | Some v -> v
	   | None -> failwith "BlackHole" (*TBR*))
     | v -> v

let assignV (VarV r) v  = r := v;unitV
let updateV (ArrV a) (IntV i) v  = a.(Int32Rep.to_int i) <- v;unitV (* TBR *)
let indexV (ArrV a) (IntV i) = a.(Int32Rep.to_int i) (*TBR*)
let applyV (FuncV f) v k = f v k
let rec derefV v =
    match v with
    | VarV r -> !r

let notV (BoolV b) = BoolV (not b)
let async_of_V(AsyncV async) = async
let set_result async v =
  	match async with
	| {result=None;waiters=waiters} ->
        async.result <- Some v;
        async.waiters <- [];
        List.fold_left (fun runnables waiter -> (fun () -> waiter v)::runnables) [] waiters; 
	| {result=Some _} -> failwith "set_result"
let get_result async k =
  	match async with
	| {result=Some v} -> k v
	| {result=None;waiters} -> (async.waiters <- k::waiters; unitV)

let rec debug_string_of_val v =
    match v with
    | NullV  -> "null"
    | BoolV b -> if b then "true" else "false"
    | NatV n -> Natural.to_string_u n
    | IntV i -> Integer.to_string_s i
    | Word8V w -> Word8.to_string_u w
    | Word16V w -> Word16.to_string_u w
    | Word32V w -> Word32.to_string_u w
    | Word64V w -> Word64.to_string_u w
    | FloatV f -> Float.to_string f
    | CharV d -> sprintf "(Char %li)" d (* TBR *)
    | TextV t -> t (* TBR *)
    | TupV vs -> sprintf "(%s)" (String.concat "," (List.map (debug_string_of_val) vs))
    | ObjV ve -> sprintf "{%s}" (String.concat ";" (List.map (fun (v,w) ->
    	              	                  sprintf "%s=%s " v (debug_string_of_val w)) (Env.bindings ve)))
    | ArrV a ->
       sprintf "[%s]" (String.concat ";" (List.map debug_string_of_val  (Array.to_list a)))
    | OptV o ->
      (match o with
      | None -> "null"
      | Some v -> sprintf "Some (%s)" (debug_string_of_val v))
    | FuncV f ->
    	"<func>"
    | VarV r ->
    	sprintf "Var (%s)" (debug_string_of_val !r) (*TBR show address ?*)
    | RecV r ->
	sprintf "Rec (%s)" (debug_string_of_val (OptV r.definition))
    | AsyncV async ->
      "<async>"

let rec string_of_atomic_val context t v =
  match norm_typ context t with
  | AnyT -> "any"
  | PrimT p ->
    (match p with
    | NullT -> let _ = null_of_V v in "null"
    | IntT ->  Integer.to_string_s (int_of_V v)
    | BoolT -> if (bool_of_V v) then "true" else "false"
    | FloatT -> Float.to_string (float_of_V v)
    | NatT -> Natural.to_string_u (nat_of_V v)
    | CharT -> sprintf "%i" (Int32.to_int(char_of_V v)) (* TBR *)
    | WordT Width8 ->
        let w = word8_of_V v in
        Word8.to_string_u w
    | WordT Width16 ->
        let w = word16_of_V v in
        Word16.to_string_u w
    | WordT Width32 ->
        let w = word32_of_V v in
        Word32.to_string_u w
    | WordT Width64->
        let w = word64_of_V v in
        Word64.to_string_u w
    | TextT -> text_of_V v)
  | VarT (c,[]) ->
     Con.to_string c
  | VarT (c,ts) ->
     sprintf "%s<%s>" (Con.to_string c) (String.concat "," (List.map string_of_typ ts))
  | TupT ts ->
    let vs = tup_of_V v in
    sprintf "(%s)"  (String.concat "," (List.map2 (string_of_val context) ts vs))
  | ObjT(Object,fs) ->
    let ve = obj_of_V v in
    sprintf "{%s}" (String.concat ";" (List.map (fun {var;mut;typ} ->
    	              	                 let v = checkV (Env.find var ve) in
					 let v = match mut with
					         | VarMut -> derefV v
						 | ConstMut -> v
				         in
                                       sprintf "%s=%s " var (string_of_atomic_val context typ v))
                    fs))
  | _ ->
    sprintf "(%s)" (string_of_val context t v)

and string_of_val context t v =
  match norm_typ context t with
  | ArrayT (m,t) ->
    let a = arr_of_V v in
    sprintf "%s[%s]" (match m with VarMut -> " var " |  ConstMut -> "")
    	       (String.concat ";" (List.map (string_of_val context t) (Array.to_list a)))
  | FuncT(_,_,_) ->
    ignore (func_of_V v); (* catch errors *)
    "<func>"
  | OptT t ->
    let v = opt_of_V v in
    (match v with
    | None -> "null"
    | Some v -> sprintf "Some %s" (string_of_val context t v))
  | AsyncT t ->
    let {result;waiters} = async_of_V v in
    sprintf "async{%s,%i}" (match result with
                            | None -> "?"
           		      | Some v -> string_of_val context t v)
			      (List.length waiters)
  | LikeT t -> 
    sprintf "like %s" (string_of_atomic_typ t) (* TBR *)
  | ObjT(Actor,fs) ->
    sprintf "actor%s" (string_of_atomic_val context (ObjT(Object,fs)) v)
  | _ -> string_of_atomic_val context t v



  