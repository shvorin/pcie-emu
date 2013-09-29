/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */


#ifndef CCID_DEFS_H
#define CCID_DEFS_H


#define CCID_Base 0xED3EF9A9BB066D65
#define CCID_Issue 0x81266946FF4BE5B3
#define CCID_T3d_OldConf 0xA18451485AE2B187
#define CCID_Control 0x6F916C02F6F77C6E
#define CCID_OperationMode 0x27F700BE4F3D2315
#define CCID_PortDesc 0xB6BFA6BEF5E45912
#define CCID_Channels 0xEF752FB8B40FC1E8
#define CCID_SkifCh2 0xD47F63F3A1AFEAF4
#define CCID_T3d_Network 0xA0D5265CEB46CEF0
#define CCID_T3d_Node 0x37B4A7D60BBE765A
#define CCID_meta_align_0 0x274CCB3B3094FFD6

#define CCID_Dbg_T3d_Node 0xD9690861C1A6AD1E
#define CCID_Dbg_ILink 0xED3EA4FFA0375773
#define CCID_Dbg_Credit 0x3BD63E7362A256D2
#define CCID_Dbg_IVC 0xFACD24A5A76E60EE


#define DECLARE_CC(macro) {CCID_ ## macro, "" # macro}

static const char *ccid2name(uint64_t ccid) {
  /* FIXME: implemented as linear search */

  struct cc_desc {
    uint64_t ccid;
    char *name;
  };

  static struct cc_desc known_classes[] = {
    DECLARE_CC(Base),
    DECLARE_CC(Issue),
    DECLARE_CC(T3d_OldConf),
    DECLARE_CC(Control),
    DECLARE_CC(OperationMode),
    DECLARE_CC(PortDesc),
    DECLARE_CC(Channels),
    DECLARE_CC(SkifCh2),
    DECLARE_CC(T3d_Network),
    DECLARE_CC(T3d_Node),
    DECLARE_CC(Dbg_T3d_Node),
    DECLARE_CC(Dbg_ILink),
    DECLARE_CC(Dbg_Credit),
    DECLARE_CC(Dbg_IVC),
    DECLARE_CC(meta_align_0),
  };

  int i;
  for(i=0; i<sizeof(known_classes)/sizeof(struct cc_desc); ++i)
    if(known_classes[i].ccid == ccid)
      return known_classes[i].name;

  return NULL;
}

#undef DECLARE_CC

#endif /* CCID_DEFS_H */
