# Headers representation

Because of the level of abstraction of a Request, different representations
of the headers must be used. The following levels are proposed:

  * Raw headers. The full headers as a string. This is the lowest level.
    This is necessary to keep a total control on the headers, with
    the option to insert any illegal character at any point.
  * Headers as a Hash. Highest level of abstraction. Mainly used by end-user
    for trivial cases and quick access to standard headers.
    (e.g., `{"Host" => "127.0.0.1", "X-Forwarded-For" => "192.168.1.1"}`)
  * Headers as an Array. This is an intermediate level of abstraction.
    This level would mainly be used for internal processing (e.g., adding a 
    header), without disturbing or merging other headers (limit the 
    collateral effects).

# Constraints

  *  One and only one of these levels will be used as reference. In our 
     case, this reference is raw headers.


