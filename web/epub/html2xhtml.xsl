<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
     <xsl:output encoding="UTF-8" indent="yes" method="xml" omit-xml-declaration="yes"
        doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
        doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
        />

    <xsl:template match="/">
        <result>
            <xsl:apply-templates select="//body/*" />
        </result>
    </xsl:template>

    <xsl:template match="@*|text()|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|*|text()" />
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>