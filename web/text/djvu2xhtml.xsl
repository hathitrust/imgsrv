<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:exsl="http://exslt.org/common"
    xmlns:str="http://exslt.org/strings"
    extension-element-prefixes="exsl str">

    <xsl:output encoding="UTF-8" indent="yes" method="xml" omit-xml-declaration="yes"
       doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
       doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
       />

    <xsl:param name="margin" select="number(40)" />
    <xsl:param name="dir" select="'auto'" />

    <xsl:variable name="page-width" select="//BODY/OBJECT/@width" />

    <xsl:template match="/">
        <html>
            <head>
                <title><xsl:value-of select="//BODY/OBJECT/PARAM[@name='PAGE']/@value" /></title>
            </head>
            <body>
                <xsl:apply-templates select="//OBJECT" />
            </body>
        </html>
    </xsl:template>

    <xsl:template match="OBJECT">
        <div class="ocr_page">
            <xsl:attribute name="data-coords">
                <xsl:text>0 0 </xsl:text>
                <xsl:value-of select="@width" />
                <xsl:text> </xsl:text>
                <xsl:value-of select="@height" />
            </xsl:attribute>
            <xsl:if test="normalize-space($dir)">
                <xsl:attribute name="dir"><xsl:value-of select="$dir" /></xsl:attribute>
            </xsl:if>
            <xsl:apply-templates />
        </div>
    </xsl:template>

    <xsl:template match="PARAGRAPH">
        <xsl:variable name="lines-data">
            <block>
                <xsl:for-each select="LINE">
                    <xsl:apply-templates select="." />
                </xsl:for-each>
            </block>
        </xsl:variable>
        <xsl:variable name="lines" select="exsl:node-set($lines-data)//span[@class='ocr_line']" />
        
        <!-- <xsl:apply-templates select="$lines" mode="copy" /> -->

        <p class="ocr_par" data-lines="{count($lines)}">
            <!-- <xsl:apply-templates /> -->
            <xsl:for-each select="$lines">
                <xsl:variable name="index" select="position()" />
                <xsl:apply-templates select="." mode="copy">
                    <xsl:with-param name="previous-line" select="$lines[$index - 1]" />
                </xsl:apply-templates>
            </xsl:for-each>
        </p>
    </xsl:template>

    <xsl:template match="LINE">
        <xsl:variable name="line-data">
            <xsl:apply-templates />
        </xsl:variable>
        <xsl:variable name="line" select="exsl:node-set($line-data)" />
        <xsl:if test="normalize-space($line)">
            <span class="ocr_line">
                <xsl:variable name="a" select="$line/span[1]" />
                <xsl:variable name="b" select="$line/span[last()]" />
                <xsl:variable name="x" select="$b/@data-xmax div $page-width" />
                <xsl:attribute name="data-width">
                    <xsl:value-of select="$x" />
                </xsl:attribute>
                <xsl:if test="$x &lt; 0.75">
                    <xsl:attribute name="data-line-break">true</xsl:attribute>
                </xsl:if>
                <xsl:apply-templates select="$line/*|$line/text()" mode="copy" />
            </span>
        </xsl:if>
    </xsl:template>

    <xsl:template match="WORD">
        <xsl:variable name="coords" select="str:split(@coords, ',')" />
        <xsl:variable name="xmin" select="$coords[1]" />
        <xsl:variable name="ymin" select="$coords[4]" />
        <xsl:variable name="xmax" select="$coords[3]" />
        <xsl:variable name="ymax" select="$coords[2]" />

        <span class="ocrx_word">
            <xsl:attribute name="data-coords">
                <xsl:value-of select="$xmin" />
                <xsl:text> </xsl:text>
                <xsl:value-of select="$ymin" />
                <xsl:text> </xsl:text>
                <xsl:value-of select="$xmax" />
                <xsl:text> </xsl:text>
                <xsl:value-of select="$ymax" />
            </xsl:attribute>
            <xsl:attribute name="data-xmax"><xsl:value-of select="$xmax" /></xsl:attribute>
            <xsl:value-of select="." />
        </span>
        <xsl:text> </xsl:text>
    </xsl:template>

    <xsl:template match="span[@class='ocr_line']" mode="copy" priority="99">
        <xsl:param name="previous-line" />
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="copy" />
            <xsl:attribute name="data-previous-line"><xsl:value-of select="string-length(normalize-space($previous-line))" /></xsl:attribute>
            <xsl:if test="$previous-line and @data-line-break = 'true'">
                <xsl:if test="$previous-line/@data-line-break != 'true'">
                    <xsl:attribute name="data-end-paragraph">true</xsl:attribute>
                </xsl:if>
            </xsl:if>
            <!-- <xsl:if test="string-length(normalize-space(.)) &lt; $margin">
                <xsl:attribute name="data-line-break">true</xsl:attribute>
                <xsl:if test="string-length(normalize-space($previous-line)) &gt;= $margin">
                    <xsl:attribute name="data-end-paragraph">true</xsl:attribute>
                </xsl:if>
            </xsl:if> -->
            <xsl:apply-templates select="*|text()" mode="copy" />
        </xsl:copy>
    </xsl:template>

    <xsl:template match="@*|*|text()" mode="copy">
        <xsl:copy>
            <xsl:apply-templates select="@*|*|text()" mode="copy" />
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>