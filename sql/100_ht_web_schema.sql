USE ht;
DROP TABLE IF EXISTS `access_stmts`;
CREATE TABLE `access_stmts` (
  `stmt_key` varchar(32) NOT NULL DEFAULT '',
  `stmt_url` text NOT NULL,
  `stmt_head` text NOT NULL,
  `stmt_text` text NOT NULL,
  `stmt_url_aux` text,
  `stmt_icon` text,
  `stmt_icon_aux` text,
  PRIMARY KEY (`stmt_key`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

LOCK TABLES `access_stmts` WRITE;

INSERT INTO `access_stmts` (`stmt_key`, `stmt_url`, `stmt_head`, `stmt_text`, `stmt_url_aux`, `stmt_icon`, `stmt_icon_aux`)
VALUES
  ('pd','http://www.hathitrust.org/access_use#pd','Public Domain','We have determined this work to be in the public domain, meaning that it is not subject to copyright. Users are free to copy, use, and redistribute the work in part or in whole. It is possible that current copyright holders, heirs or the estate of the authors of individual portions of the work, such as illustrations or photographs, assert copyrights over these portions. Depending on the nature of subsequent use that is made, additional rights may need to be obtained independently of anything we can address.',NULL,NULL,NULL),
  ('pd-google','http://www.hathitrust.org/access_use#pd-google','Public Domain, Google-digitized','We have determined this work to be in the public domain, meaning that it is not subject to copyright. Users are free to copy, use, and redistribute the work in part or in whole. It is possible that current copyright holders, heirs or the estate of the authors of individual portions of the work, such as illustrations or photographs, assert copyrights over these portions. Depending on the nature of subsequent use that is made, additional rights may need to be obtained independently of anything we can address. The digital images and OCR of this work were produced by Google, Inc. (indicated by a watermark on each page in the PageTurner). Google requests that the images and OCR not be re-hosted, redistributed or used commercially. The images are provided for educational, scholarly, non-commercial purposes.',NULL,NULL,NULL),
  ('pd-us','http://www.hathitrust.org/access_use#pd-us','Public Domain in the United States','We have determined this work to be in the public domain in the United States of America. It may not be in the public domain in other countries. Copies are provided as a preservation service. Particularly outside of the United States, persons receiving copies should make appropriate efforts to determine the copyright status of the work in their country and use the work accordingly. It is possible that current copyright holders, heirs or the estate of the authors of individual portions of the work, such as illustrations or photographs, assert copyrights over these portions. Depending on the nature of subsequent use that is made, additional rights may need to be obtained independently of anything we can address. ',NULL,NULL,NULL),
  ('pd-us-google','http://www.hathitrust.org/access_use#pd-us-google','Public Domain in the United States, Google-digitized','We have determined this work to be in the public domain in the United States of America. It may not be in the public domain in other countries. Copies are provided as a preservation service. Particularly outside of the United States, persons receiving copies should make appropriate efforts to determine the copyright status of the work in their country and use the work accordingly. It is possible that current copyright holders, heirs or the estate of the authors of individual portions of the work, such as illustrations or photographs, assert copyrights over these portions. Depending on the nature of subsequent use that is made, additional rights may need to be obtained independently of anything we can address. The digital images and OCR of this work were produced by Google, Inc. (indicated by a watermark on each page in the PageTurner). Google requests that the images and OCR not be re-hosted, redistributed or used commercially. The images are provided for educational, scholarly, non-commercial purposes.',NULL,NULL,NULL),
  ('oa','http://www.hathitrust.org/access_use#oa','Open Access','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law). It is made available from HathiTrust with explicit permission of the copyright holder. Permission must be requested from the rights holder for any subsequent use.',NULL,NULL,NULL),
  ('oa-google','http://www.hathitrust.org/access_use#oa-google','Open Access, Google-digitized','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law). It is made available from HathiTrust with permission of the copyright holder. Permission must be requested from the rights holder for any subsequent use. The digital images and OCR of this work were produced by Google, Inc. (indicated by a watermark on each page in thePageTurner). Google requests that these images and OCR not be re-hosted, redistributed or used commercially. They are provided for educational, scholarly, non-commercial purposes.',NULL,NULL,NULL),
  ('ic-access','http://www.hathitrust.org/access_use#ic-access','Protected by copyright law','Protected by copyright law but made available on a strictly limited basis in accordance with the statutory limitations including, but not limited to, Section 107 provisions for fair use, Section 108 provisions for libraries and archives, and the rights provided to registered users with disabilities. In the absence of an applicable exception, no further reproduction or distribution is permitted by any means without the permission of the copyright holder.Lawful uses of works are provided only under the following conditions: Print copies of relevant works in HathiTrust must be owned currently or have been owned previously by the institution\'s library system. Access to persons who have print disabilities: Users must be members of a partner institution in a country where laws permit access to users who have print disabilities. Users must be authenticated into HathiTrust. Users must be certified by the partner institution as having a print disability or as being a proxy for a person who has a print disability. Section 108 (17 USC §108) replacement, preservation, and distribution uses of digital materials: Users must be located within the United States on the premises of a HathiTrust member institution library. Member authentication at the institution may be required. The number of users who can access a given digital copy at a time is determined by the number of print copies held (or previously held) in the library system. If a library system only has one print copy, only one user at a time will be able to access the digital copy.\n',NULL,NULL,NULL),
  ('ic','http://www.hathitrust.org/access_use#ic','Protected by copyright law','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law).  In the absence of an applicable exception, no further reproduction or distribution is permitted by any means without the permission of the copyright holder.',NULL,NULL,NULL),
  ('cc-by','http://www.hathitrust.org/access_use#cc-by','Creative Commons Attribution','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law) but made available under a Creative Commons Attribution license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by/4.0.','https://creativecommons.org/licenses/by/3.0/us/',NULL,'https://i.creativecommons.org/l/by/3.0/us/80x15.png'),
  ('cc-by-nd','http://www.hathitrust.org/access_use#cc-by-nd','Creative Commons Attribution-NoDerivatives','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law) but made available under a Creative Commons Attribution-NoDerivatives license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). Only verbatim copies of this work may be made, distributed, displayed, and performed, not derivative works based upon it. Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by-nd/4.0.\n','https://creativecommons.org/licenses/by-nd/3.0/us/',NULL,'https://i.creativecommons.org/l/by-nd/3.0/us/80x15.png'),
  ('cc-by-nc-nd','http://www.hathitrust.org/access_use#cc-by-nc-nd','Creative Commons Attribution-NonCommercial-NoDerivatives','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but made available under a Creative Commons Attribution-NonCommercial-NoDerivatives license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). Only verbatim copies of this work may be made, distributed, displayed, and performed, not derivative works based upon it. Copies that are made may only be used for non-commercial purposes. Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by-nc-nd/4.0.','https://creativecommons.org/licenses/by-nc-nd/3.0/us/',NULL,'https://i.creativecommons.org/l/by-nc-nd/3.0/us/80x15.png'),
  ('cc-by-nc','http://www.hathitrust.org/access_use#cc-by-nc','Creative Commons Attribution-NonCommercial','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but made available under a Creative Commons Attribution-NonCommercial license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). This work may be copied, distributed, displayed, and performed - and derivative works based upon it - but for non-commercial purposes only (if you are unsure where a use is non-commercial, contact the rights holder for clarification). Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed http://creativecommons.org/licenses/by-nc/4.0.','https://creativecommons.org/licenses/by-nc/3.0/us/',NULL,'https://i.creativecommons.org/l/by-nc/3.0/us/80x15.png'),
  ('cc-by-nc-sa','http://www.hathitrust.org/access_use#cc-by-nc-sa','Creative Commons Attribution-NonCommercial-ShareAlike','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but made available under a Creative Commons Attribution-NonCommercial-ShareAlike license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). This work may be copied, distributed, displayed, and performed - and derivative works based upon it - but for non-commercial purposes only (if you are unsure where a use is non-commercial, contact the rights holder for clarification). If you alter, transform, or build upon this work, you may distribute the resulting work only under the same or similar license to this one. Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by-nc-sa/4.0.','https://creativecommons.org/licenses/by-nc-sa/3.0/us/',NULL,'https://i.creativecommons.org/l/by-nc-sa/3.0/us/80x15.png'),
  ('cc-by-sa','http://www.hathitrust.org/access_use#cc-by-sa','Creative Commons Attribution-ShareAlike','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but made available under a Creative Commons Attribution-ShareAlike license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). If you alter, transform, or build upon this work, you may distribute the resulting work only under the same or similar license to this one. Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by-sa/4.0.','https://creativecommons.org/licenses/by-sa/3.0/us/',NULL,'https://i.creativecommons.org/l/by-sa/3.0/us/80x15.png'),
  ('cc-zero','http://www.hathitrust.org/access_use#cc-zero','Creative Commons Zero (CC0)','This work has been dedicated by the rights holder to the public domain. It is not protected by copyright and may be reproduced and distributed freely without permission. For details, see the full license deed at http://creativecommons.org/publicdomain/zero/1.0/.','https://creativecommons.org/publicdomain/zero/1.0/',NULL,'https://i.creativecommons.org/l/zero/1.0/80x15.png'),
  ('candidates','http://www.lib.umich.edu/orphan-works/access-and-use#candidates','Orphan Works Candidate','Protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law). In the absence of an applicable exception, no further reproduction or distribution is permitted by any means without the permission of the copyright holder.',NULL,NULL,NULL),
  ('orphans','http://www.lib.umich.edu/orphan-works/access-and-use#orphans','Orphan Works','Access is provided for the purpose of reading for the same people with the right to check out these works from the Library\'s print collection for scholarly and educational purposes. Readers are reminded that the books are subject to copyright and that the library is providing access for the purpose of reading the titles as an exercise of fair use under 17 USC 107. Further use may or may not be permitted by law; readers must make their own assessment of the legal implications of any subsequent use.',NULL,NULL,NULL),
  ('by-permission','http://www.hathitrust.org/access_use#by-permission','Available by Permission','This work may be protected by copyright law. It is made available in HathiTrust with explicit permission of the copyright holder, assignee, or transferee. Permission must be requested from the appropriate party (indicated in the HathiTrust catalog record) for any subsequent use.',NULL,NULL,NULL),
  ('ic-us','http://www.hathitrust.org/access_use#ic-us','In Copyright in the United States','This work is in copyright in the United States of America (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but in the Public Domain outside the United States. Outside the United States, users are free to copy, use, and redistribute the work in part or in whole. It is possible that heirs or the estate of the authors of individual portions of the work, such as illustrations, assert copyrights over these portions. Depending on the nature of subsequent use that is made, additional rights may need to be obtained independently of anything we can address.',NULL,NULL,NULL),
  ('ic-us-google','http://www.hathitrust.org/access_use#ic-us-google','In Copyright in the United States, Google-digitized','This work is in copyright in the United States of America (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but in the Public Domain outside the United States. Outside the United States, users are free to copy, use, and redistribute the work in part or in whole. It is possible that heirs or the estate of the authors of individual portions of the work, such as illustrations, assert copyrights over these portions. Depending on the nature of subsequent use that is made, additional rights may need to be obtained independently of anything we can address.The digital images and OCR of this work were produced by Google, Inc. (indicated by a watermark on each page in the PageTurner). Google requests that the images and OCR not be re-hosted, redistributed or used commercially. The images are provided for educational, scholarly, non-commercial purposes.',NULL,NULL,NULL),
  ('cc-by-3.0','http://www.hathitrust.org/access_use#cc-by-3.0','Creative Commons Attribution','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law) but made available under a Creative Commons Attribution license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by/3.0/.','https://creativecommons.org/licenses/by/3.0/',NULL,'https://i.creativecommons.org/l/by/3.0/80x15.png'),
  ('cc-by-nd-3.0','http://www.hathitrust.org/access_use#cc-by-nd-3.0','Creative Commons Attribution-NoDerivatives','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law) but made available under a Creative Commons Attribution-NoDerivatives license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). Only verbatim copies of this work may be made, distributed, displayed, and performed, not derivative works based upon it. Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by-nd/3.0/.\n','https://creativecommons.org/licenses/by-nd/3.0/',NULL,'https://i.creativecommons.org/l/by-nd/3.0/80x15.png'),
  ('cc-by-nc-nd-3.0','http://www.hathitrust.org/access_use#cc-by-nc-nd-3.0','Creative Commons Attribution-NonCommercial-NoDerivatives','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but made available under a Creative Commons Attribution-NonCommercial-NoDerivatives license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). Only verbatim copies of this work may be made, distributed, displayed, and performed, not derivative works based upon it. Copies that are made may only be used for non-commercial purposes. Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by-nc-nd/3.0/.','https://creativecommons.org/licenses/by-nc-nd/3.0/',NULL,'https://i.creativecommons.org/l/by-nc-nd/3.0/80x15.png'),
  ('cc-by-nc-3.0','http://www.hathitrust.org/access_use#cc-by-nc-3.0','Creative Commons Attribution-NonCommercial','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but made available under a Creative Commons Attribution-NonCommercial license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). This work may be copied, distributed, displayed, and performed - and derivative works based upon it - but for non-commercial purposes only (if you are unsure where a use is non-commercial, contact the rights holder for clarification). Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed http://creativecommons.org/licenses/by-nc/3.0/.','https://creativecommons.org/licenses/by-nc/3.0/',NULL,'https://i.creativecommons.org/l/by-nc/3.0/80x15.png'),
  ('cc-by-nc-sa-3.0','http://www.hathitrust.org/access_use#cc-by-nc-sa-3.0','Creative Commons Attribution-NonCommercial-ShareAlike','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but made available under a Creative Commons Attribution-NonCommercial-ShareAlike license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). This work may be copied, distributed, displayed, and performed - and derivative works based upon it - but for non-commercial purposes only (if you are unsure where a use is non-commercial, contact the rights holder for clarification). If you alter, transform, or build upon this work, you may distribute the resulting work only under the same or similar license to this one. Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by-nc-sa/3.0/.','https://creativecommons.org/licenses/by-nc-sa/3.0/',NULL,'https://i.creativecommons.org/l/by-nc-sa/3.0/80x15.png'),
  ('cc-by-sa-3.0','http://www.hathitrust.org/access_use#cc-by-sa-3.0','Creative Commons Attribution-ShareAlike','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but made available under a Creative Commons Attribution-ShareAlike license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). If you alter, transform, or build upon this work, you may distribute the resulting work only under the same or similar license to this one. Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by-sa/3.0/.','https://creativecommons.org/licenses/by-sa/3.0/',NULL,'https://i.creativecommons.org/l/by-sa/3.0/80x15.png'),
  ('cc-by-4.0','http://www.hathitrust.org/access_use#cc-by-4.0','Creative Commons Attribution','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law) but made available under a Creative Commons Attribution license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). For details, see the full license deed at http://creativecommons.org/licenses/by/4.0/.','https://creativecommons.org/licenses/by/4.0/',NULL,'https://i.creativecommons.org/l/by/4.0/80x15.png'),
  ('cc-by-nd-4.0','http://www.hathitrust.org/access_use#cc-by-nd-4.0','Creative Commons Attribution-NoDerivatives','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law) but made available under a Creative Commons Attribution-NoDerivatives license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). Only verbatim copies of this work may be made, distributed, displayed, and performed, not derivative works based upon it. Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by-nd/4.0.\n','https://creativecommons.org/licenses/by-nd/4.0/',NULL,'https://i.creativecommons.org/l/by-nd/4.0/80x15.png'),
  ('cc-by-nc-nd-4.0','http://www.hathitrust.org/access_use#cc-by-nc-nd-4.0','Creative Commons Attribution-NonCommercial-NoDerivatives','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but made available under a Creative Commons Attribution-NonCommercial-NoDerivatives license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). Only verbatim copies of this work may be made, distributed, displayed, and performed, not derivative works based upon it. Copies that are made may only be used for non-commercial purposes. Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by-nc-nd/4.0.','https://creativecommons.org/licenses/by-nc-nd/4.0/',NULL,'https://i.creativecommons.org/l/by-nc-nd/4.0/80x15.png'),
  ('cc-by-nc-4.0','http://www.hathitrust.org/access_use#cc-by-nc-4.0','Creative Commons Attribution-NonCommercial','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but made available under a Creative Commons Attribution-NonCommercial license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). This work may be copied, distributed, displayed, and performed - and derivative works based upon it - but for non-commercial purposes only (if you are unsure where a use is non-commercial, contact the rights holder for clarification). Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed http://creativecommons.org/licenses/by-nc/4.0.','https://creativecommons.org/licenses/by-nc/4.0/',NULL,'https://i.creativecommons.org/l/by-nc/4.0/80x15.png'),
  ('cc-by-nc-sa-4.0','http://www.hathitrust.org/access_use#cc-by-nc-sa-4.0','Creative Commons Attribution-NonCommercial-ShareAlike','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but made available under a Creative Commons Attribution-NonCommercial-ShareAlike license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). This work may be copied, distributed, displayed, and performed - and derivative works based upon it - but for non-commercial purposes only (if you are unsure where a use is non-commercial, contact the rights holder for clarification). If you alter, transform, or build upon this work, you may distribute the resulting work only under the same or similar license to this one. Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by-nc-sa/4.0.','https://creativecommons.org/licenses/by-nc-sa/4.0/',NULL,'https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png'),
  ('cc-by-sa-4.0','http://www.hathitrust.org/access_use#cc-by-sa-4.0','Creative Commons Attribution-ShareAlike','This work is protected by copyright law (which includes certain exceptions to the rights of the copyright holder that users may make, such as fair use where applicable under U.S. law), but made available under a Creative Commons Attribution-ShareAlike license. You must attribute this work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work). If you alter, transform, or build upon this work, you may distribute the resulting work only under the same or similar license to this one. Please check the terms of the specific Creative Commons license as indicated at the item level. For details, see the full license deed at http://creativecommons.org/licenses/by-sa/4.0.','https://creativecommons.org/licenses/by-sa/4.0/',NULL,'https://i.creativecommons.org/l/by-sa/4.0/80x15.png'),
  ('pd-pvt','http://www.hathitrust.org/access_use#pd-pvt','Public Domain, Privacy Concerns','We have determined this work to be in the public domain, but access is limited due to privacy concerns. See the HathiTrust Privacy Policy for more information. The link for \"Privacy Policy\" is http://www.hathitrust.org/privacy#pd-pvt.',NULL,NULL,NULL);

UNLOCK TABLES;

DROP TABLE IF EXISTS `access_stmts_map`;
CREATE TABLE `access_stmts_map` (
  `a_attr` varchar(32) NOT NULL DEFAULT '',
  `a_access_profile` varchar(32) NOT NULL DEFAULT '',
  `stmt_key` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`a_attr`,`a_access_profile`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

LOCK TABLES `access_stmts_map` WRITE;

INSERT INTO `access_stmts_map` (`a_attr`, `a_access_profile`, `stmt_key`)
VALUES
  ('cc-by','google','cc-by'),
  ('cc-by','open','cc-by'),
  ('cc-by','page','cc-by'),
  ('cc-by','page+lowres','cc-by'),
  ('cc-by-3.0','google','cc-by-3.0'),
  ('cc-by-3.0','open','cc-by-3.0'),
  ('cc-by-3.0','page','cc-by-3.0'),
  ('cc-by-3.0','page+lowres','cc-by-3.0'),
  ('cc-by-4.0','google','cc-by-4.0'),
  ('cc-by-4.0','open','cc-by-4.0'),
  ('cc-by-4.0','page','cc-by-4.0'),
  ('cc-by-4.0','page+lowres','cc-by-4.0'),
  ('cc-by-nc','google','cc-by-nc'),
  ('cc-by-nc','open','cc-by-nc'),
  ('cc-by-nc','page','cc-by-nc'),
  ('cc-by-nc','page+lowres','cc-by-nc'),
  ('cc-by-nc-3.0','google','cc-by-nc-3.0'),
  ('cc-by-nc-3.0','open','cc-by-nc-3.0'),
  ('cc-by-nc-3.0','page','cc-by-nc-3.0'),
  ('cc-by-nc-3.0','page+lowres','cc-by-nc-3.0'),
  ('cc-by-nc-4.0','google','cc-by-nc-4.0'),
  ('cc-by-nc-4.0','open','cc-by-nc-4.0'),
  ('cc-by-nc-4.0','page','cc-by-nc-4.0'),
  ('cc-by-nc-4.0','page+lowres','cc-by-nc-4.0'),
  ('cc-by-nc-nd','google','cc-by-nc-nd'),
  ('cc-by-nc-nd','open','cc-by-nc-nd'),
  ('cc-by-nc-nd','page','cc-by-nc-nd'),
  ('cc-by-nc-nd','page+lowres','cc-by-nc-nd'),
  ('cc-by-nc-nd-3.0','google','cc-by-nc-nd-3.0'),
  ('cc-by-nc-nd-3.0','open','cc-by-nc-nd-3.0'),
  ('cc-by-nc-nd-3.0','page','cc-by-nc-nd-3.0'),
  ('cc-by-nc-nd-3.0','page+lowres','cc-by-nc-nd-3.0'),
  ('cc-by-nc-nd-4.0','google','cc-by-nc-nd-4.0'),
  ('cc-by-nc-nd-4.0','open','cc-by-nc-nd-4.0'),
  ('cc-by-nc-nd-4.0','page','cc-by-nc-nd-4.0'),
  ('cc-by-nc-nd-4.0','page+lowres','cc-by-nc-nd-4.0'),
  ('cc-by-nc-sa','google','cc-by-nc-sa'),
  ('cc-by-nc-sa','open','cc-by-nc-sa'),
  ('cc-by-nc-sa','page','cc-by-nc-sa'),
  ('cc-by-nc-sa','page+lowres','cc-by-nc-sa'),
  ('cc-by-nc-sa-3.0','google','cc-by-nc-sa-3.0'),
  ('cc-by-nc-sa-3.0','open','cc-by-nc-sa-3.0'),
  ('cc-by-nc-sa-3.0','page','cc-by-nc-sa-3.0'),
  ('cc-by-nc-sa-3.0','page+lowres','cc-by-nc-sa-3.0'),
  ('cc-by-nc-sa-4.0','google','cc-by-nc-sa-4.0'),
  ('cc-by-nc-sa-4.0','open','cc-by-nc-sa-4.0'),
  ('cc-by-nc-sa-4.0','page','cc-by-nc-sa-4.0'),
  ('cc-by-nc-sa-4.0','page+lowres','cc-by-nc-sa-4.0'),
  ('cc-by-nd','google','cc-by-nd'),
  ('cc-by-nd','open','cc-by-nd'),
  ('cc-by-nd','page','cc-by-nd'),
  ('cc-by-nd','page+lowres','cc-by-nd'),
  ('cc-by-nd-3.0','google','cc-by-nd-3.0'),
  ('cc-by-nd-3.0','open','cc-by-nd-3.0'),
  ('cc-by-nd-3.0','page','cc-by-nd-3.0'),
  ('cc-by-nd-3.0','page+lowres','cc-by-nd-3.0'),
  ('cc-by-nd-4.0','google','cc-by-nd-4.0'),
  ('cc-by-nd-4.0','open','cc-by-nd-4.0'),
  ('cc-by-nd-4.0','page','cc-by-nd-4.0'),
  ('cc-by-nd-4.0','page+lowres','cc-by-nd-4.0'),
  ('cc-by-sa','google','cc-by-sa'),
  ('cc-by-sa','open','cc-by-sa'),
  ('cc-by-sa','page','cc-by-sa'),
  ('cc-by-sa','page+lowres','cc-by-sa'),
  ('cc-by-sa-3.0','google','cc-by-sa-3.0'),
  ('cc-by-sa-3.0','open','cc-by-sa-3.0'),
  ('cc-by-sa-3.0','page','cc-by-sa-3.0'),
  ('cc-by-sa-3.0','page+lowres','cc-by-sa-3.0'),
  ('cc-by-sa-4.0','google','cc-by-sa-4.0'),
  ('cc-by-sa-4.0','open','cc-by-sa-4.0'),
  ('cc-by-sa-4.0','page','cc-by-sa-4.0'),
  ('cc-by-sa-4.0','page+lowres','cc-by-sa-4.0'),
  ('cc-zero','google','cc-zero'),
  ('cc-zero','open','cc-zero'),
  ('cc-zero','page','cc-zero'),
  ('cc-zero','page+lowres','cc-zero'),
  ('ic','google','ic'),
  ('ic','open','ic'),
  ('ic','page','ic'),
  ('ic','page+lowres','ic'),
  ('ic-world','google','oa-google'),
  ('ic-world','open','oa'),
  ('ic-world','page','oa'),
  ('ic-world','page+lowres','oa'),
  ('icus','google','ic-us-google'),
  ('icus','open','ic-us'),
  ('icus','page','ic-us'),
  ('icus','page+lowres','ic-us'),
  ('nobody','google','ic'),
  ('nobody','open','ic'),
  ('nobody','page','ic'),
  ('nobody','page+lowres','ic'),
  ('op','google','ic-access'),
  ('op','open','ic-access'),
  ('op','page','ic-access'),
  ('op','page+lowres','ic-access'),
  ('orph','google','orphans'),
  ('orph','open','orphans'),
  ('orph','page','orphans'),
  ('orph','page+lowres','orphans'),
  ('orphcand','google','candidates'),
  ('orphcand','open','candidates'),
  ('orphcand','page','candidates'),
  ('orphcand','page+lowres','candidates'),
  ('pd','google','pd-google'),
  ('pd','open','pd'),
  ('pd','page','pd'),
  ('pd','page+lowres','pd'),
  ('pd-pvt','google','pd-pvt'),
  ('pd-pvt','open','pd-pvt'),
  ('pd-pvt','page','pd-pvt'),
  ('pd-pvt','page+lowres','pd-pvt'),
  ('pdus','google','pd-us-google'),
  ('pdus','open','pd-us'),
  ('pdus','page','pd-us'),
  ('pdus','page+lowres','pd-us'),
  ('umall','google','ic'),
  ('umall','open','ic'),
  ('umall','page','ic'),
  ('umall','page+lowres','ic'),
  ('und','google','ic'),
  ('und','open','ic'),
  ('und','page','ic'),
  ('und','page+lowres','ic'),
  ('und-world','google','by-permission'),
  ('und-world','open','by-permission'),
  ('und-world','page','by-permission'),
  ('und-world','page+lowres','by-permission');
UNLOCK TABLES;

# Dump of table ht_institutions
# ------------------------------------------------------------

DROP TABLE IF EXISTS `ht_institutions`;
CREATE TABLE `ht_institutions` (
  `sdrinst` varchar(32) NOT NULL DEFAULT ' ',
  `inst_id` varchar(64) DEFAULT NULL,
  `grin_instance` varchar(8) DEFAULT NULL,
  `name` varchar(256) NOT NULL DEFAULT ' ',
  `template` varchar(256) NOT NULL DEFAULT ' ',
  `authtype` varchar(32) NOT NULL DEFAULT 'shibboleth',
  `domain` varchar(32) NOT NULL DEFAULT ' ',
  `us` tinyint(1) NOT NULL DEFAULT '0',
  `mapto_domain` varchar(32) DEFAULT NULL,
  `mapto_sdrinst` varchar(32) DEFAULT NULL,
  `mapto_inst_id` varchar(32) DEFAULT NULL,
  `mapto_name` varchar(256) DEFAULT NULL,
  `mapto_entityID` varchar(256) DEFAULT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT '0',
  `orph_agree` tinyint(1) NOT NULL DEFAULT '0',
  `entityID` varchar(256) DEFAULT NULL,
  `allowed_affiliations` text,
  `shib_authncontext_class` varchar(255) DEFAULT NULL,
  `emergency_status` text,
  `emergency_contact` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`sdrinst`),
  KEY `ht_institutions_inst_id` (`inst_id`),
  KEY `ht_institutions_mapto_inst_id` (`mapto_inst_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



# Dump of table ht_users
# ------------------------------------------------------------

DROP TABLE IF EXISTS `ht_users`;
CREATE TABLE `ht_users` (
  `userid` varchar(256) NOT NULL DEFAULT '',
  `displayname` varchar(128) DEFAULT NULL,
  `email` varchar(128) DEFAULT NULL,
  `activitycontact` varchar(128) DEFAULT NULL,
  `approver` varchar(128) DEFAULT NULL,
  `authorizer` varchar(128) DEFAULT NULL,
  `usertype` varchar(32) DEFAULT NULL,
  `role` varchar(32) DEFAULT NULL,
  `access` varchar(32) DEFAULT 'normal',
  `expires` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `expire_type` varchar(32) DEFAULT NULL,
  `iprestrict` varchar(1024) DEFAULT NULL,
  `mfa` tinyint(1) DEFAULT NULL,
  `identity_provider` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`userid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

LOCK TABLES `ht_users` WRITE;
INSERT INTO `ht_users` (`userid`, `usertype`, `role`, `expires`, `expire_type`)
VALUES ('bjensen', 'cataloging', 'normal', NOW() + INTERVAL 1 YEAR, 'expiresanually' );
UNLOCK TABLES;


DROP TABLE IF EXISTS `ht_sessions`;
CREATE TABLE `ht_sessions` (
  `id` varchar(32) NOT NULL DEFAULT '',
  `a_session` longblob,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `ht_counts`;
CREATE TABLE `ht_counts` (
  `userid` varchar(256) NOT NULL DEFAULT '',
  `accesscount` int(11) NOT NULL DEFAULT '0',
  `last_access` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `warned` tinyint(1) NOT NULL DEFAULT '0',
  `certified` tinyint(1) NOT NULL DEFAULT '0',
  `auth_requested` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `pt_exclusivity_ng`;
CREATE TABLE `pt_exclusivity_ng` (
  `lock_id` varchar(32) NOT NULL,
  `item_id` varchar(32) NOT NULL DEFAULT '',
  `owner` varchar(256) NOT NULL DEFAULT '',
  `affiliation` varchar(128) NOT NULL DEFAULT '',
  `expires` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `renewals` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`lock_id`,`owner`,`affiliation`),
  KEY `lock_check` (`lock_id`,`affiliation`),
  KEY `excess_check` (`lock_id`,`affiliation`,`expires`),
  KEY `pt_exclusivity_ng_expires` (`expires`),
  KEY `pt_exclusivity_ng_item_id` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=COMPRESSED;
