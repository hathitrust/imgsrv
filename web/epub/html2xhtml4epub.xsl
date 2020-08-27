<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
     <xsl:output encoding="UTF-8" indent="yes" method="xml" omit-xml-declaration="yes"
        doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
        doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
        />

    <xsl:param name="width" />
    <xsl:param name="height" />
    <xsl:param name="image_src" />

    <xsl:template match="/">
        <html>
            <head>
                <xsl:if test="normalize-space($width)">
                    <meta name="viewport" content="width={$width},height={$height}" />
                </xsl:if>
                <!-- <meta name="http-equiv" content="text/html; charset=utf-8" /> -->
                <link href="../styles/stylesheet.css" rel="stylesheet" type="text/css" />
            </head>
            <body>
                <xsl:if test="normalize-space($image_src)">
                    <xsl:attribute name="class">pre-paginated</xsl:attribute>
                    <figure>
                        <img src="{$image_src}" />
                    </figure>
                </xsl:if>
                <xsl:apply-templates select="//body/*" />
            </body>
        </html>
    </xsl:template>

<!--     <xsl:template match="*" priority="99">
        <xsl:element name="{name(.)}" namespace="http://www.w3.org/1999/xhtml">
            <xsl:apply-templates select="@*|*|text()" />
        </xsl:element>
    </xsl:template> -->

    <xsl:template match="@*|text()|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|*|text()" />
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>