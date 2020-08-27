<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
     <xsl:output encoding="UTF-8" indent="yes" method="xml" omit-xml-declaration="yes"
        doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
        doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
        />

    <xsl:param name="title" />

    <xsl:template match="/">
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <title><xsl:value-of select="$title" /></title>
            </head>
            <body>
                <xsl:apply-templates select="//pages/*" />
                <p class="watermark">
                    <img class="watermark-digitized" src="watermark_digitized.png" />
                    <img class="watermark-oriinal" src="watermark_original.png" />
                </p>
            </body>
        </html>
    </xsl:template>

    <xsl:template match="@*|text()">
        <xsl:copy>
            <xsl:apply-templates select="@*|*|text()" />
        </xsl:copy>
    </xsl:template>

    <xsl:template match="node()">
        <xsl:element name="{name(.)}" namespace="http://www.w3.org/1999/xhtml">
            <xsl:apply-templates select="@*|*|text()" />
        </xsl:element>
    </xsl:template>

</xsl:stylesheet>
