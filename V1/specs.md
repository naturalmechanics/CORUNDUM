Corundum v1: Deterministic Document Engineering Format
-----------------------------------------------------------------------------
Official Specification | Document Extension: .cortx | Style Extension: .corst
-----------------------------------------------------------------------------

# 0. Design Intent

Corundum is a deterministic, streaming-parseable document engineering format. 
Unlike traditional markup, Corundum is defined as a structural document protocol rather than a lightweight markup language.

It is engineered for:

    => Plain-Text Legibility: Native human-readability without specialized tooling.
    => Explicit Boundaries: Elimination of structural ambiguity via mandatory delimiters.
    => Parser Determinism: Strict, predictable behavior for high-integrity systems.
    => Semantic Embedding: Deep integration of machine-readable metadata.
    => LLM-Safe Generation: Minimized hallucinatory structural errors during AI synthesis.
    => Downstream Independence: Decoupled rendering across PDF, HTML, Console, and AST targets.



# 1. Conceptual Model


A Corundum document is modeled as a deterministic traversal of a bounded 2D manifold (the Page) 
by a pen following a space-filling curve.

The parser is strictly responsible for building a Structural Abstract Syntax Tree (AST); 
it does not render. Rendering engines consume the AST to produce visual output.

1.1 Core Abstractions
----------------

    => Page: The primary rendering target (Default: ISO 216 A4).
    => Flow: The default linear progression of content.
    => Zone: A structured region that overrides or modifies flow semantics.
    => Hole: A container for non-flow embedded objects or data.
    => Directive: A functional instruction encapsulated within a Hole.
    => Delimiter: A mandatory structural boundary; structure is never inferred from indentation.



# 2. Parsing Guarantees

Corundum v1 mandates the following parser constraints:

    => Single-Pass Streaming: O(n) time complexity.
    => Heuristic-Free: No statistical or "best-guess" structure detection.
    => Zero Ambiguity: No constructs requiring context-dependent interpretation.
    => Deterministic Priority: Fixed evaluation order for all line starts.
    => Bounded Lookahead: The parser must operate line-by-line with minimal buffer.




# 3. Default Reference Model

In the absence of external .corst configuration, the following rendering defaults apply:

    Attribute	        |   Specification
    -------------------------------------
    Page Size	        |   DIN A4
    Background Color	|   HEX ECEEDD
    Text Color	        |   HEX 0D264F
    Typeface	        |   Tex Gyre Termes (Corundum dependency)
    Font Size 	        |   px 12
    Line Spacing        |   Font Default
    Margins	            |   cm 2.4 all sides
    Justification	    |   Full
    Borders             |   None 
    Corner Radius	    |   None
    Flow Curve          |   TV Scan
    -------------------------------------



# 4. Rune Handling


The fundamental unit of Corundum is the Rune.

A Rune is a symbol drawn from a finite, predefined set. Each Rune possesses intrinsic properties -
most notably its shape - which are sufficiently stable and well-defined to allow consistent rendering across a document.

Text characters are Runes. However, the concept extends beyond text. Electrical symbols, weather icons, 
musical notation, and other standardized graphical symbols may also qualify as Runes, provided their 
visual form is unambiguous and fixed within the document’s context.

By contrast, chemical symbols, although standardized in meaning, may not qualify as Runes 
if their visual representation varies within the same document. Corundum distinguishes 
between semantic standardization and graphical determinism: only symbols with stable, 
renderer-independent form are considered Runes.

The precise visual realization of a Rune is the responsibility of the renderer.

In the absence of structural modifiers or flow-altering constructs, 
the renderer emits Runes along a predefined FlowCurve across the page.


4.1 Normalization, Breaks, and Indentations
---------------


### 4.1.1 Normalization

* Line Breaks:          All line endings MUST be normalized to LF (\n).
* Tabs:                 All tab characters MUST be normalized (converted to spaces) prior to parsing.

### 4.1.2 Blank Lines

    * Blank Line:                   A line containing exclusively horizontal whitespace (spaces/tabs) preceding an LF.
                                    The renderer ignores a single blank line.
    * Double Blank Line:            Two consecutive Blank Lines. Acts as a mandatory structural terminator.
                                    The renderer handels this as a paragraph break.
    * Multiple (>2) Blank Lines:    More than 2 blank lines will be normalized to a double blank line.

### 4.1.3 Indentation

The indentation unit is defined as exactly four (4) spaces.

    * For a prefix of k spaces: nesting_level = floor(k / 4).
    * Remainder spaces are discarded.
    * Constraint: Indentation defines structure only within List contexts.





4.2 Rune Styling 
---------------

Runes are styled through an external Skin File.
The file extension for a Skin File is:

`*.corst`

A Skin File defines named style rules that may be applied to bounded regions of Runes within a .cortx document.




### 4.2.1 Including the Skin File

A Skin File must be explicitly included at the beginning of a .cortx file.

The include directive syntax is:

`!INCLUDE SkinFileName.corst`

    - Inclusion Rules
        -- Position Requirement
            --- The include directive must be the first non-empty line of the document.
            --- If any non-whitespace character precedes it, the parser shall 
                not recognize the directive and shall treat it as plain text.
    
        --  Token Structure
            --- The ! symbol must be in the sameline as the keyword INCLUDE.
            --- No line break is permitted between them.
            --- Horizontal whitespace, such as space or tab, is permitted between the ! symbol and the keyword INCLUDE
            --- At least one horizontal whitespace (space or tab) must separate INCLUDE and the file name.
            --- No line break is permitted between INCLUDE and the file name.
    
        -- Termination
            --- The directive must terminate with at least one line break.
            --- Two line breaks are recommended to visually separate the directive from document content.
    
        -- File Name Constraints
            --- The file name must end in .corst.
            --- Only one Skin File may be included in Corundum v1.
            --- Multiple include directives are invalid and the v1 parser will treat additional directives as normal text.



#### 4.2.2 Applying a Style

A style is applied to a bounded region of Runes using a pipe-delimited construct.

Syntax: `|| [StyleTag] Styled content ||`

    - Structural Rules
        -- Delimiters
            --- A styled region begins with a double pipe ||.
            --- It terminates with a closing double pipe ||.
            --- The first matching closing delimiter after the opening delimiter terminates the region.
            --- Nested styled regions are not permitted in Corundum v1.
    
        -- StyleTag Placement
            --- The StyleTag must appear immediately after the opening ||, enclosed in square brackets [ ].
            --- At least one horizontal whitespace between the opening || and the opening `[` is recommended 
                for readability, but not required.
            --- After the closing `]`, all horizontal whitespace up to the first non-whitespace Rune is ignored by the renderer.
            --- Vertical whitespace (line breaks) inside [StyleTag] is not permitted.
    
        -- Closing Whitespace Handling
            --- All contiguous horizontal whitespace immediately preceding the closing || is ignored by the renderer.
            --- Internal whitespace within the styled region is otherwise preserved according to standard flow rules.
    
        -- Single StyleTag Constraint
            --- Exactly one `[StyleTag]` is permitted per styled region.
            --- Additional bracketed tags inside the same region are invalid, and the parser won't recognize it
            --- Sub-styling or nested styles are not supported in v1.
    
    
    
    - StyleTag Definition Rules
    
        A StyleTag is an alphanumeric identifier subject to the following constraints:
    
        -- First Character: Must be an alphabetic character `[A–Z]` or `[a–z]`.
        -- Subsequent Characters: May contain:
            --- Alphabetic characters
            --- Numeric digits
            --- Underscores _
        -- Prohibited:
            --- Leading digits
            --- Leading underscores
            --- Whitespace
            --- Special characters other than underscore
            --- Line breaks

The StyleTag must correspond to a style definition declared in the included .corst file.
If no matching style exists, the parser must still construct the styled region node; 
however, the renderer may fall back to a default behavior.




### 4.2.3 StyleTag as a Semantic Indicator

A StyleTag may serve both as:

    1. visual styling directive, and
    2. A semantic marker.

Example:

` || [Important] Nunc pellentesque tortor ligula, a tristique ipsum lobortis mollis. ||`

Even if the renderer applies no visual distinction, the bounded content is semantically marked as Important.
This enables:

    - Structural querying
    - Semantic indexing
    - Conditional rendering
    - Machine-level interpretation

The StyleTag therefore carries semantic weight independent of visual styling. 
The renderer may ignore visual transformation, but it must not discard the semantic classification encoded in the AST.



### 4.2.4 Conflict and Ambiguity Resolution

To preserve determinism in v1:

    - Pipe delimiters || are recognized only in FLOW context.
    - A || sequence encountered inside an already-open styled region is treated as a closing delimiter.
    - There is an mechanism for literal || as well as a single pipe inside a styled region.
    - Nested styled regions are syntactically invalid.
    - Multiple adjacent styled regions are valid and parsed sequentially.

This ensures:

    - Single-pass deterministic parsing
    - No lookahead beyond matching delimiter
    - No ambiguity between pipes used as text and pipes used as style markers (since pipes have no other reserved meaning in v1)


# 5. Style Definitions


Styles inside a .corst file are defined using bracket-delimited blocks.
Each style definition consists of:

    - An outer bracket block defining the style.
    - A style identifier line.
    - An inner bracket block containing attribute declarations.

The Syntax is: 

    [
    
        StyleTag !!
    
        [
            FontColor: RGB AABBCC
            FontFace:  string "Cormorant Regular"
    
        ]
    
    ]

    [
    
        anotherStyleTag !!
    
        [
            FontColor: .....
            FontFace:  .....
    
        ]
    
    ]

etc. 

5.1 Comments
----------------

Comments are enclosed between //== and ==//.  

    - Only single-line comments are permitted in v1.
    - The opening marker //== and closing marker ==// must appear on the same line.
    - Multi-line comments are not supported.
    - Comments may appear:
        -- On otherwise empty lines.
        -- After valid syntax on the same line.
    - Comments are stripped during lexical preprocessing before parsing.

5.2 Syntax of a style 
----------------

    - The entire style definition is enclosed within a pair of brackets:
    
    [
    ...
    ]
    
        -- The opening [ and closing ] of the outer block must each appear on their own line.
        -- No other characters are permitted on those lines except optional whitespace.
        -- Immediately following the opening bracket, the next non-empty, non-comment line must contain the StyleTag declaration.
    
    - The StyleTag declaration must follow this structure:

StyleTag !!


        -- The StyleTag must conform to the same lexical constraints defined for .cortx files:
            --- First character: alphabetic [A–Z a–z]
            --- Subsequent characters: alphanumeric or underscore
            --- No leading digits
            --- No leading underscore
            --- No special characters except underscore
            --- No vertical whitespace
        -- The StyleTag must be followed by exactly two exclamation marks: !!
        -- No line break is allowed between the StyleTag and !!
        -- Horizontal whitespace between the StyleTag and !! is permitted but not required
        -- No additional tokens may appear on the same line (excluding comments)
    
    - Following the StyleTag line, an inner bracket block must appear:
    
    [
        Attribute declarations
    ]
    
        -- The opening [ must be on its own line.
        -- The closing ] must be on its own line.
        -- Between them, one or more attribute lines may appear.
        -- Only attribute declarations and comments are allowed inside the inner block.
    
    - Each attribute must follow this strict structure:

`AttributeName : Type/Unit Value`

    -- The entire attribute declaration must occupy a single line (v1 constraint).
    -- Around the colon :, horizontal whitespace is permitted.
    -- No vertical whitespace is permitted within the declaration.
    -- At least one horizontal whitespace is required between Type/Unit and Value.
    -- No comma syntax is used in v1.
    -- Duplicate attribute names within the same style block are invalid in v1.

    - The syntax requires the type or unit to precede the value.
    
    Examples:
    
    FontColor : RGBHEX AABBCC
    FontColor : RGB AABBCC
    FontFace  : string "Cormorant Regular"
    FontSize  : px 32
    
        This ensures:
    
        -- Strong syntactic determinism
        -- Clear separation between semantic intent (Type/Unit) and payload (Value)
        -- Easier static validation



5.3 Multiple styles in the same File
----------------

A .corst file may contain multiple style definitions.

    -- Style blocks must appear sequentially.
    -- The closing bracket ] of a style block must be followed by at least one line break
    -- The next style block must begin with an opening bracket [ on its own line
    -- Nested style blocks are not permitted.
    -- Duplicate StyleTag names within the same .corst file are invalid.

5.4 Page Styles 
----------------

After all individual style definitions, a Global Page Block may be declared.
This block defines properties that apply to the entire document manifold.


### 5.4.1 Global Delimiter
The transition from style definitions to global page attributes is marked by a Global Separator.
The separator is: ........

    - It must consist of eight or more consecutive periods.
    - The separator must appear on a line by itself.
    - It must be preceded by a Double Blank Line.
    - It must be followed by a Double Blank Line.
    - It may only appear once in a .corst file.
    - It is valid only inside .corst files (never in .cortx).



### 5.4.2 Attribute Syntax

Within the Global Page Block, attributes follow the same syntax as style attributes:

AttributeName : Type/Unit Value

    - Each attribute must occupy a single line.
    - Duplicate attributes override earlier declarations (last-write-wins).
    - Only attribute declarations and comments are permitted.

### 5.4.3 Supported Global Attributes

    Global attributes override the Default Reference Model and include, but are not limited to:
    Attribute	Description	                                            Examples
    PageSize	Defines the physical dimensions of the manifold.	    ISO A4, ANSI Letter
    PageColor	Sets the canvas background value.	                    RGBHEX ECEEDD
    FlowCurve	Defines the mathematical path of the "pen" traversal.	SpaceFilling Hilbert, Linear Z-Order
    PageShape	Defines the geometric bound                             Rectangular, Custom SVG

Example:

    [
        bodyText !!
        [
            FontFace : string "Tex Gyre Termes"
        ]
    ]
    
    ........
    
    PageSize   : ISO A4
    PageColor  : RGBHEX ECEEDD
    FlowCurve  : string "Hilbert"


# 6. Escapes


$$ : Force a single Line break (the renderer ignores single line breaks. $$ forces a single line break)
$_ : Force a single Blank space 

\backsl     : Backslash
\obrk       : Opening bracket
\cbrk       : Closing bracket 
\pipe       : A single vertical pipe 
\doublepipe : Double vertical pipes
\exclaim    : Exclaimation mark

    - Escapes are handled in the Renderer.
    - Escaped symbols are treated as literal Runes.
    - Escapes may not span lines.
    - Invalid escape sequences are treated as renderer errors.

6.1 Reserved Exclamation Mark
----------------

In Corundum v1:

The ! character is not interpreted in normal text flow. It is reserved for future control directives.
Authors are strongly discouraged from using ! in flow text. Future versions may assign semantic meaning to !.
