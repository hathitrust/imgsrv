<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:exsl="http://exslt.org/common"
    xmlns:str="http://exslt.org/strings"
    xmlns:alto="http://www.loc.gov/standards/alto/ns-v2#"
    extension-element-prefixes="exsl str">

    <xsl:output encoding="UTF-8" indent="no" method="xml" omit-xml-declaration="yes"
       doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
       doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
       />

    <xsl:param name="margin" select="number(40)" />
    <xsl:param name="dir" select="'auto'" />
    <xsl:variable name="page-width">
        <xsl:variable name="page" select="//alto:Page|//Page" />
        <xsl:choose>
            <xsl:when test="$page/@WIDTH = 0">
                <xsl:variable name="node" select="$page/alto:PrintSpace|$page/PrintSpace" />
                <xsl:value-of select="$node/@HPOS + $node/@WIDTH + $node/@HPOS" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$page/@WIDTH" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:template match="/">
        <html>
            <head>
                <title>
                    <xsl:call-template name="build-title">
                        <xsl:with-param name="page" select="//alto:Page|//Page" />
                    </xsl:call-template>
                </title>
            </head>
            <body>
                <xsl:apply-templates select="//alto:Page|//Page" />
            </body>
        </html>
    </xsl:template>

    <xsl:template name="build-title">
        <xsl:param name="page" />
        <xsl:value-of select="$page/@ID" />
        <xsl:if test="$page/@PHYSICAL_IMG_NR">
            <xsl:text>: </xsl:text>
            <xsl:value-of select="$page/@PHYSICAL_IMG_NR" />
        </xsl:if>
    </xsl:template>

    <xsl:template match="alto:Page|Page">
        <div class="ocr_page" data-page-width="{$page-width}">
            <xsl:if test="normalize-space($dir)">
                <xsl:attribute name="dir"><xsl:value-of select="$dir" /></xsl:attribute>
            </xsl:if>
            <xsl:if test="count(alto:PrintSpace/alto:TextBlock) = 1 or count(PrintSpace/TextBlock) = 1">
                <xsl:attribute name="data-force-breaks">true</xsl:attribute>
            </xsl:if>
            <xsl:choose>
                <xsl:when test="@HEIGHT = 0 and @WIDTH = 0">
                    <xsl:call-template name="build-data-coords">
                        <xsl:with-param name="node" select="alto:PrintSpace|PrintSpace" />
                    </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:attribute name="data-coords">
                        <xsl:text>0 0 </xsl:text>
                        <xsl:value-of select="@WIDTH" />
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="@HEIGHT" />
                    </xsl:attribute>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:apply-templates select="alto:PrintSpace|PrintSpace" />
        </div>
    </xsl:template>

    <xsl:template name="build-data-coords">
        <xsl:param name="node" />
        <xsl:attribute name="data-coords">
            <xsl:text>0 0 </xsl:text>
            <xsl:value-of select="@HPOS + @WIDTH + @HPOS" />
            <xsl:text> </xsl:text>
            <xsl:value-of select="@VPOS + @HEIGHT + ( @VPOS div 2 )" />
        </xsl:attribute>
    </xsl:template>

    <xsl:template match="alto:TextBlock|TextBlock">
        <xsl:message>AHOY TEXT BLOCK</xsl:message>
        <xsl:variable name="lines-data">
            <block>
                <xsl:for-each select="alto:TextLine|TextLine">
                    <xsl:apply-templates select="." />
                </xsl:for-each>
            </block>
        </xsl:variable>
        <xsl:variable name="lines" select="exsl:node-set($lines-data)//block/span" />
        <p class="ocr_par">
            <xsl:for-each select="$lines">
                <xsl:variable name="index" select="position()" />
                <xsl:apply-templates select="." mode="copy">
                    <xsl:with-param name="previous-line" select="$lines[$index - 1]" />
                </xsl:apply-templates>
                <!-- <xsl:choose>
                    <xsl:when test="@length &lt; $margin and $lines[$i + 1]/@length &lt; $margin" >
                        <br />
                    </xsl:when>
                </xsl:choose> -->
            </xsl:for-each>
        </p>
    </xsl:template>

    <xsl:template match="alto:TextLine|TextLine">
        <xsl:variable name="line-data">
            <line>
                <xsl:apply-templates mode="fill" />
                <xsl:text> </xsl:text>
            </line>
        </xsl:variable>
        <xsl:variable name="line" select="exsl:node-set($line-data)" />
        <!-- <span class="ocr_line"><xsl:copy-of select="$line" /></span> -->
        <xsl:if test="normalize-space($line//line)">
            <span class="ocr_line">
                <xsl:variable name="b" select="$line/line/span[last()]" />
                <xsl:variable name="x" select="$b/@data-xmax div $page-width" />
                <xsl:attribute name="data-width">
                    <xsl:value-of select="$x" />
                </xsl:attribute>
                <xsl:attribute name="data-line-width"><xsl:value-of select="$b/@data-xmax" /></xsl:attribute>
                <xsl:if test="$x &lt; 0.75">
                    <xsl:attribute name="data-line-break">true</xsl:attribute>
                </xsl:if>

                <xsl:for-each select="$line//line">
                    <xsl:apply-templates select="*|text()" mode="copy" />
                </xsl:for-each>
            </span>
        </xsl:if>
    </xsl:template>

    <xsl:template match="alto:String|String" mode="fill">
        <!-- <xsl:value-of select="@CONTENT" /> -->
        <span class="ocrx_word">
            <xsl:attribute name="data-coords">
                <xsl:value-of select="@HPOS" />
                <xsl:text> </xsl:text>
                <xsl:value-of select="@VPOS" />
                <xsl:text> </xsl:text>
                <xsl:value-of select="@WIDTH + @HPOS" />
                <xsl:text> </xsl:text>
                <xsl:value-of select="@HEIGHT + @VPOS" />
            </xsl:attribute>
            <xsl:attribute name="data-xmax"><xsl:value-of select="@WIDTH + @HPOS" /></xsl:attribute>
            <xsl:value-of select="@CONTENT" />
        </span>
    </xsl:template>

    <xsl:template match="alto:SP|SP" mode="fill">
        <xsl:text> </xsl:text>
    </xsl:template>

    <xsl:template match="text()" mode="fill" />

    <xsl:template match="span[@class='ocr_line']" mode="copy" priority="99">
        <xsl:param name="previous-line" />
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="copy" />
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