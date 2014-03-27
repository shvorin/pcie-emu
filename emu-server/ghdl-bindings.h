/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */


#ifndef GHDL_BINDINGS_H
#define GHDL_BINDINGS_H


/*
 * See http://ghdl.free.fr/ghdl/Restrictions-on-foreign-declarations.html about
 * enumeration types representation: std_logic is represented by 8 bits word.
 *
 * NB: here char value is wrapped into structure to prevent using 0 and 1
 * instead of stdl_0 and stdl_1.
 */

#pragma pack(push,1)

typedef struct {
  char val;
} std_logic;

#pragma pack(pop)

/*
    TYPE std_ulogic IS ( 'U',  -- Uninitialized
                         'X',  -- Forcing  Unknown
                         '0',  -- Forcing  0
                         '1',  -- Forcing  1
                         'Z',  -- High Impedance
                         'W',  -- Weak     Unknown
                         'L',  -- Weak     0
                         'H',  -- Weak     1
                         '-'   -- Don't care
                       );
*/
static const std_logic stdl_0 = {2}, stdl_1 = {3};

static int std_logic_eq(std_logic a, std_logic b) { return a.val == b.val; }

#endif /* GHDL_BINDINGS_H */
