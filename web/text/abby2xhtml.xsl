<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:str="http://exslt.org/strings"
    extension-element-prefixes="str">
     <xsl:output encoding="UTF-8" indent="yes" method="xml" omit-xml-declaration="yes"
        doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
        doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
        />

    <xsl:param name="margin" select="number(40)" />
    <xsl:param name="dir" select="'auto'" />

    <xsl:variable name="page-width">
        <xsl:variable name="coords" select="str:split(substring-before(//div[@class='ocr_page']/@title, ';'))" />
        <xsl:value-of select="$coords[4]" />
    </xsl:variable>
 
    <xsl:template match="/">
        <html>
            <head>
                <xsl:apply-templates select="//head/title" mode="copy" />
                <xsl:apply-templates select="//head/meta" mode="copy" />
            </head>
            <body>
                <xsl:apply-templates select="//div[@class='ocr_page']" mode="copy" />
            </body>
        </html>
    </xsl:template>

    <xsl:template match="@style" priority="99" mode="copy" />
    <xsl:template match="@title" priority="99" mode="copy">
        <!-- <xsl:attribute name="data-title"><xsl:value-of select="." /></xsl:attribute> -->
    </xsl:template>

    <xsl:template match="@*|*|text()" mode="copy">
        <xsl:copy>
            <xsl:apply-templates select="@*|*|text()" mode="copy" />
        </xsl:copy>
    </xsl:template>

    <xsl:template match="br" mode="copy" priority="99" />

    <xsl:template match="span[@class='ocr_line']" mode="copy" priority="99">
        <xsl:param name="previous-line" />
        <xsl:variable name="line-width">
            <xsl:variable name="coords" select="str:split(substring-before(@title, ';'))" />
            <xsl:value-of select="$coords[4]" />
        </xsl:variable>
        <xsl:variable name="x" select="$line-width div $page-width" />
        <xsl:variable name="line" select="normalize-space(.)" />
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="copy" />
            <xsl:attribute name="data-width">
                <xsl:value-of select="$x" />
            </xsl:attribute>
            <xsl:if test="$x &lt; 0.75">
                <xsl:attribute name="data-line-break">true</xsl:attribute>
                <xsl:if test="$previous-line">
                    <xsl:variable name="previous-line-width">
                        <xsl:variable name="coords" select="str:split(substring-before($previous-line/@title, ';'))" />
                        <xsl:value-of select="$coords[4]" />
                    </xsl:variable>
                    <xsl:variable name="px" select="$previous-line-width div $page-width" />
                    <xsl:attribute name="data-px" select="$px" />
                    <xsl:if test="$px &gt;= 0.75">
                        <xsl:attribute name="data-end-paragraph">true</xsl:attribute>
                    </xsl:if>
                </xsl:if>
            </xsl:if>
            <xsl:apply-templates select="span[@class='ocrx_word']" mode="copy" />
        </xsl:copy>
    </xsl:template>

    <xsl:template match="span[@class='ocrx_word']" priority="99" mode="copy">
        <xsl:if test="normalize-space(.)">
            <xsl:copy>
                <xsl:call-template name="build-coords" />
                <xsl:apply-templates select="@*|text()" mode="copy" />
            </xsl:copy>
            <xsl:text> </xsl:text>
        </xsl:if>
    </xsl:template>

    <xsl:template match="span" mode="copy" priority="90">
        <xsl:variable name="word">
            <xsl:value-of select="." />
            <xsl:text> ? </xsl:text>
        </xsl:variable>
        <xsl:value-of select="$word" />
    </xsl:template>

    <xsl:template match="p[@class='ocr_par']" mode="copy" priority="99">
        <xsl:variable name="lines" select="span[@class='ocr_line']" />
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="copy" />
            <xsl:for-each select="$lines">
                <xsl:variable name="index" select="position()" />
                <xsl:apply-templates select="." mode="copy">
                    <xsl:with-param name="previous-line" select="$lines[$index -1]" />
                </xsl:apply-templates>
            </xsl:for-each>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="div[@class='ocr_page']" mode="copy" priority="99">
        <xsl:copy>
            <xsl:call-template name="build-coords" />
            <xsl:if test="normalize-space($dir)">
                <xsl:attribute name="dir"><xsl:value-of select="$dir" /></xsl:attribute>
            </xsl:if>
            <xsl:apply-templates select="@*|*|text()" mode="copy" />
        </xsl:copy>
    </xsl:template>

    <xsl:template match="html" mode="copy" priority="99">
        <html xmlns="http://www.w3.org/1999/xhtml">
            <xsl:apply-templates select="@*|*|text()" mode="copy" />
        </html>
    </xsl:template>

    <xsl:template match="@*|text()" mode="copy" priority="88">
        <xsl:copy>
            <xsl:apply-templates select="@*|*|text()" mode="copy" />
        </xsl:copy>
    </xsl:template>

    <xsl:template name="build-coords">
        <xsl:variable name="coords" select="str:split(substring-before(@title, ';'))" />
        <xsl:variable name="xmin" select="$coords[2]" />
        <xsl:variable name="ymin" select="$coords[3]" />
        <xsl:variable name="xmax" select="$coords[4]" />
        <xsl:variable name="ymax" select="$coords[5]" />
        <xsl:attribute name="data-coords">
            <xsl:value-of select="$xmin" />
            <xsl:text> </xsl:text>
            <xsl:value-of select="$ymin" />
            <xsl:text> </xsl:text>
            <xsl:value-of select="$xmax" />
            <xsl:text> </xsl:text>
            <xsl:value-of select="$ymax" />
        </xsl:attribute>

    </xsl:template>

<!--     <xsl:template match="*" mode="copy">
        <xsl:element name="{name(.)}" namespace="http://www.w3.org/1999/xhtml">
            <xsl:apply-templates select="@*|*|text()" mode="copy" />
        </xsl:element>
    </xsl:template> -->

</xsl:stylesheet>