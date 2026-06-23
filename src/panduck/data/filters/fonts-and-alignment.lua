--- fonts-and-alignment.lua
---
--- A Pandoc Lua Filter for advanced typography and layout control in LaTeX/PDF generation.
--- It translates standard CSS-like classes and attributes into their precise LaTeX equivalents.
---
--- Copyright: © 2026 Nandakumar Chandrasekhar
--- License: MIT - see LICENSE for details
---
--- Vendorizado en panduck (pandoc-ext/fonts-and-alignment) y parcheado para:
---   1. Soporte de salida typst (familias, pesos, tamanos, versalitas, alineacion,
---      color, casing y subrayado/tachado), no solo LaTeX/HTML.
---   2. Consumir las clases que maneja (las quita del elemento) en salida typst,
---      para que los filtros de particion (typst-slides, instagram-posts) no las
---      vuelvan a envolver. Asi este filtro es la fuente unica de estilos inline.
---   3. Aliases extra (tiny, smaller, Large, LARGE, huge, Huge, sff, strong, emph)
---      que mapean el vocabulario propio que usaban esos filtros al canonico pfa.
--- Las secciones agregadas van marcadas con "panduck".

PANDOC_VERSION:must_be_at_least('2.17')

local pandoc_lib = assert(pandoc, 'Cannot find the pandoc library')
if type(pandoc_lib) ~= 'table' then
  error('Expected variable pandoc to be a table')
end

local List = assert(pandoc.List, 'Cannot find the pandoc.List class')

-- Verify prerequisite reader extensions are enabled
if PANDOC_READER_OPTIONS and PANDOC_READER_OPTIONS.extensions then
  local ext = PANDOC_READER_OPTIONS.extensions
  if not (ext:includes('fenced_divs') and ext:includes('bracketed_spans')) then
    io.stderr:write('[fonts-and-alignment] Warning: Required extensions "fenced_divs" or "bracketed_spans" are disabled. Filter utilities may render as raw text.\n')
  end
end

-- ==============================================================================
-- STATE FLAGS
-- ==============================================================================
-- These flags track whether specific LaTeX packages are required for the current
-- document. They are globally scoped for the file but must be reset per-document
-- via the `Pandoc` lifecycle hook to prevent state-leakage in batch compilations.
local uses_pfa_blocks  = false
local uses_ulem_styles = false


-- ==============================================================================
-- SECTION 1: DATA DICTIONARIES (Optimized & Normalised)
-- ==============================================================================

-- Standard CSS3 Color Keyword Map
-- Maps named web colors to standard 6-character Hexadecimal codes (without the #)
-- for unified injection across both HTML styles and LaTeX [HTML]{} blocks.
local css_colors = {
  aliceblue            = 'F0F8FF',
  antiquewhite         = 'FAEBD7',
  aqua                 = '00FFFF',
  aquamarine           = '7FFFD4',
  azure                = 'F0FFFF',
  beige                = 'F5F5DC',
  bisque               = 'FFE4C4',
  black                = '000000',
  blanchedalmond       = 'FFEBCD',
  blue                 = '0000FF',
  blueviolet           = '8A2BE2',
  brown                = 'A52A2A',
  burlywood            = 'DEB887',
  cadetblue            = '5F9EA0',
  chartreuse           = '7FFF00',
  chocolate            = 'D2691E',
  coral                = 'FF7F50',
  cornflowerblue       = '6495ED',
  cornsilk             = 'FFF8DC',
  crimson              = 'DC143C',
  cyan                 = '00FFFF',
  darkblue             = '00008B',
  darkcyan             = '008B8B',
  darkgoldenrod        = 'B8860B',
  darkgray             = 'A9A9A9',
  darkgreen            = '006400',
  darkgrey             = 'A9A9A9',
  darkkhaki            = 'BDB76B',
  darkmagenta          = '8B008B',
  darkolivegreen       = '556B2F',
  darkorange           = 'FF8C00',
  darkorchid           = '9932CC',
  darkred              = '8B0000',
  darksalmon           = 'E9967A',
  darkseagreen         = '8FBC8F',
  darkslateblue        = '483D8B',
  darkslategray        = '2F4F4F',
  darkslategrey        = '2F4F4F',
  darkturquoise        = '00CED1',
  darkviolet           = '9400D3',
  deeppink             = 'FF1493',
  deepskyblue          = '00BFFF',
  dimgray              = '696969',
  dimgrey              = '696969',
  dodgerblue           = '1E90FF',
  firebrick            = 'B22222',
  floralwhite          = 'FFFAF0',
  forestgreen          = '228B22',
  fuchsia              = 'FF00FF',
  gainsboro            = 'DCDCDC',
  ghostwhite           = 'F8F8FF',
  gold                 = 'FFD700',
  goldenrod            = 'DAA520',
  gray                 = '808080',
  green                = '008000',
  greenyellow          = 'ADFF2F',
  grey                 = '808080',
  honeydew             = 'F0FFF0',
  hotpink              = 'FF69B4',
  indianred            = 'CD5C5C',
  indigo               = '4B0082',
  ivory                = 'FFFFF0',
  khaki                = 'F0E68C',
  lavender             = 'E6E6FA',
  lavenderblush        = 'FFF0F5',
  lawngreen            = '7CFC00',
  lemonchiffon         = 'FFFACD',
  lightblue            = 'ADD8E6',
  lightcoral           = 'F08080',
  lightcyan            = 'E0FFFF',
  lightgoldenrodyellow = 'FAFAD2',
  lightgray            = 'D3D3D3',
  lightgreen           = '90EE90',
  lightgrey            = 'D3D3D3',
  lightpink            = 'FFB6C1',
  lightsalmon          = 'FFA07A',
  lightseagreen        = '20B2AA',
  lightskyblue         = '87CEFA',
  lightslategray       = '778899',
  lightslategrey       = '778899',
  lightsteelblue       = 'B0C4DE',
  lightyellow          = 'FFFFE0',
  lime                 = '00FF00',
  limegreen            = '32CD32',
  linen                = 'FAF0E6',
  magenta              = 'FF00FF',
  maroon               = '800000',
  mediumaquamarine     = '66CDAA',
  mediumblue           = '0000CD',
  mediumorchid         = 'BA55D3',
  mediumpurple         = '9370DB',
  mediumseagreen       = '3CB371',
  mediumslateblue      = '7B68EE',
  mediumspringgreen    = '00FA9A',
  mediumturquoise      = '48D1CC',
  mediumvioletred      = 'C71585',
  midnightblue         = '191970',
  mintcream            = 'F5FFFA',
  mistyrose            = 'FFE4E1',
  moccasin             = 'FFE4B5',
  navajowhite          = 'FFDEAD',
  navy                 = '000080',
  oldlace              = 'FDF5E6',
  olive                = '808000',
  olivedrab            = '6B8E23',
  orange               = 'FFA500',
  orangered            = 'FF4500',
  orchid               = 'DA70D6',
  palegoldenrod        = 'EEE8AA',
  palegreen            = '98FB98',
  paleturquoise        = 'AFEEEE',
  palevioletred        = 'DB7093',
  papayawhip           = 'FFEFD5',
  peachpuff            = 'FFDAB9',
  peru                 = 'CD853F',
  pink                 = 'FFC0CB',
  plum                 = 'DDA0DD',
  powderblue           = 'B0E0E6',
  purple               = '800080',
  rebeccapurple        = '663399',
  red                  = 'FF0000',
  rosybrown            = 'BC8F8F',
  royalblue            = '4169E1',
  saddlebrown          = '8B4513',
  salmon               = 'FA8072',
  sandybrown           = 'F4A460',
  seagreen             = '2E8B57',
  seashell             = 'FFF5EE',
  sienna               = 'A0522D',
  silver               = 'C0C0C0',
  skyblue              = '87CEEB',
  slateblue            = '6A5ACD',
  slategray            = '708090',
  slategrey            = '708090',
  snow                 = 'FFFAFA',
  springgreen          = '00FF7F',
  steelblue            = '4682B4',
  tan                  = 'D2B48C',
  teal                 = '008080',
  thistle              = 'D8BFD8',
  tomato               = 'FF6347',
  turquoise            = '40E0D0',
  violet               = 'EE82EE',
  wheat                = 'F5DEB3',
  white                = 'FFFFFF',
  whitesmoke           = 'F5F5F5',
  yellow               = 'FFFF00',
  yellowgreen          = '9ACD32'
}

-- Mappings for Typography Styles { 'Span Command', 'Div Command' }
local latex_font_types = {
  ['pfa-font-bold']      = { 'textbf',     'bfseries'   },
  ['pfa-font-emphasis']  = { 'emph',       'em'         },
  ['pfa-font-italic']    = { 'textit',     'itshape'    },
  ['pfa-font-medium']    = { 'textmd',     'mdseries'   },
  ['pfa-font-mono']      = { 'texttt',     'ttfamily'   },
  ['pfa-font-normal']    = { 'textnormal', 'normalfont' },
  ['pfa-font-sans']      = { 'textsf',     'sffamily'   },
  ['pfa-font-serif']     = { 'textrm',     'rmfamily'   },
  ['pfa-font-slanted']   = { 'textsl',     'slshape'    },
  ['pfa-font-smallcaps'] = { 'textsc',     'scshape'    },
  ['pfa-font-upright']   = { 'textup',     'upshape'    }
}

-- Mappings for Font Sizes { 'Span Command', 'Div Command' }
local latex_font_sizes = {
  ['pfa-text-3xs']    = { 'tiny',         'tiny'         },
  ['pfa-text-2xs']    = { 'scriptsize',   'scriptsize'   },
  ['pfa-text-xs']     = { 'footnotesize', 'footnotesize' },
  ['pfa-text-s']      = { 'small',        'small'        },
  ['pfa-text-normal'] = { 'normalsize',   'normalsize'   },
  ['pfa-text-l']      = { 'large',        'large'        },
  ['pfa-text-xl']     = { 'Large',        'Large'        },
  ['pfa-text-2xl']    = { 'LARGE',        'LARGE'        },
  ['pfa-text-3xl']    = { 'huge',         'huge'         }
}

-- Mappings for Alignments { 'Span Command', 'Div Command' }
local latex_text_alignments = {
  ['pfa-align-center'] = { nil, 'centering'        },
  ['pfa-align-left']   = { nil, 'raggedright'      },
  ['pfa-align-right']  = { nil, 'raggedleft'       },
  ['pfa-block-center'] = { nil, 'pfa-block-center' },
  ['pfa-block-left']   = { nil, 'pfa-block-left'   },
  ['pfa-block-right']  = { nil, 'pfa-block-right'  }
}

-- Mappings for Text Decoration (Requires 'ulem' package)
local latex_ulem_styles = {
  ['pfa-text-uline']        = { 'uline',     'uline'     },
  ['pfa-text-uline-double'] = { 'uuline',    'uuline'    },
  ['pfa-text-uline-dashed'] = { 'dashuline', 'dashuline' },
  ['pfa-text-uline-dotted'] = { 'dotuline',  'dotuline'  },
  ['pfa-text-uline-wave']   = { 'uwave',     'uwave'     },
  ['pfa-text-strikeout']    = { 'sout',      'sout'      }
}

-- Dynamic Runtime Mapping for Legacy Aliases
-- panduck: ademas registra el nombre canonico (pfa-*) de cada alias en pfa_canon,
-- para que las tablas typst (indexadas solo por el nombre canonico) tambien
-- resuelvan los aliases. Sin esto, [x]{.large} no se estilaba en typst.
local pfa_canon = {}
local function map_aliases(target_table, alias_map)
  for legacy, modern in pairs(alias_map) do
    target_table[legacy] = target_table[modern]
    pfa_canon[legacy] = modern
  end
end

map_aliases(latex_font_types, { bold='pfa-font-bold', bf='pfa-font-bold', emphasis='pfa-font-emphasis', em='pfa-font-emphasis', italic='pfa-font-italic', it='pfa-font-italic', medium='pfa-font-medium', md='pfa-font-medium', monospace='pfa-font-mono', tt='pfa-font-mono', normalfont='pfa-font-normal', nf='pfa-font-normal', sans='pfa-font-sans', sf='pfa-font-sans', serif='pfa-font-serif', rm='pfa-font-serif', slanted='pfa-font-slanted', sl='pfa-font-slanted', smallcaps='pfa-font-smallcaps', sc='pfa-font-smallcaps', upright='pfa-font-upright', up='pfa-font-upright' })
map_aliases(latex_font_sizes, { xsmall='pfa-text-xs', small='pfa-text-s', normal='pfa-text-normal', large='pfa-text-l', xlarge='pfa-text-xl', xxlarge='pfa-text-2xl', huge='pfa-text-3xl' })
map_aliases(latex_text_alignments, { centering='pfa-align-center', raggedleft='pfa-align-right', raggedright='pfa-align-left' })
map_aliases(latex_ulem_styles, { uline='pfa-text-uline', u='pfa-text-uline', uuline='pfa-text-uline-double', uu='pfa-text-uline-double', dashuline='pfa-text-uline-dashed', dau='pfa-text-uline-dashed', dotuline='pfa-text-uline-dotted', dou='pfa-text-uline-dotted', uwave='pfa-text-uline-wave', uw='pfa-text-uline-wave', sout='pfa-text-strikeout', so='pfa-text-strikeout' })

-- panduck: aliases del vocabulario propio que usaban typst-slides / instagram-posts,
-- para que ahora resuelvan al canonico pfa (este filtro es la fuente unica inline).
map_aliases(latex_font_types, { sff='pfa-font-sans', strong='pfa-font-bold', emph='pfa-font-emphasis' })
map_aliases(latex_font_sizes, { tiny='pfa-text-3xs', smaller='pfa-text-2xs', Large='pfa-text-xl', LARGE='pfa-text-2xl', huge='pfa-text-3xl', Huge='pfa-text-3xl' })


-- ==============================================================================
-- SECTION 2: INITIALIZATION & COMMAND BUILDERS
-- ==============================================================================
local raw_code_function = { Span = pandoc.RawInline, Div = pandoc.RawBlock }
local latex_cmd_for_tags = { Span = {}, Div = {} }

-- Translates the configuration dictionaries into actionable LaTeX syntax strings
local function create_latex_codes(styles_list, span_end_code, div_is_env)
  for class, latex_codes in pairs(styles_list) do
    if next(latex_codes) then
      local span_code, div_code = latex_codes[1], latex_codes[2]
      if span_code then
        latex_cmd_for_tags.Span[class] = span_end_code and { '\\' .. span_code .. '{', '}' } or { '\\' .. span_code .. ' ', nil }
      end
      if div_code then
        latex_cmd_for_tags.Div[class] = div_is_env and { '\\begin{' .. div_code .. '}', '\\end{' .. div_code .. '}' } or { '{\\' .. div_code .. ' ', '}' }
      end
    end
  end
end

create_latex_codes(latex_font_types, true, false)
create_latex_codes(latex_font_sizes, false, false)
create_latex_codes(latex_text_alignments, false, true)

for class, codes in pairs(latex_ulem_styles) do
  latex_cmd_for_tags.Span[class] = { '\\' .. codes[1] .. '{', '}' }
end

local known_pfa_classes = {
  ['pfa-uppercase'] = true,
  ['pfa-lowercase'] = true,
}
for _, dict in ipairs({ latex_font_types, latex_font_sizes,
                        latex_text_alignments, latex_ulem_styles }) do
  for class_name in pairs(dict) do
    if class_name:match('^pfa%-') then known_pfa_classes[class_name] = true end
  end
end


-- ==============================================================================
-- SECTION 2b: TYPST SUPPORT (panduck)
-- ==============================================================================
-- typst no tiene cambios genericos de familia (no hay \sffamily); las familias
-- sans/mono se resuelven con el nombre de fuente del head.yaml (sansfont/monofont)
-- o una lista de respaldo. El resto (pesos, estilo, tamanos, alineacion, color,
-- casing, subrayado) mapea directo. Las versalitas son sinteticas para que
-- funcionen aunque la fuente no traiga la feature OpenType smcp.
local stringify = pandoc.utils.stringify

local typst_font_open = {
  ['pfa-font-bold']     = '#strong[',
  ['pfa-font-emphasis'] = '#emph[',
  ['pfa-font-italic']   = '#emph[',
  ['pfa-font-medium']   = '#text(weight: "medium")[',
  ['pfa-font-normal']   = '#text(weight: "regular", style: "normal")[',
  ['pfa-font-slanted']  = '#emph[',
  ['pfa-font-upright']  = '#text(style: "normal")[',
  -- smallcaps y familias (sans/serif/mono) se construyen aparte
}

local typst_size_em = {
  ['pfa-text-3xs'] = 0.6, ['pfa-text-2xs'] = 0.7, ['pfa-text-xs'] = 0.8,
  ['pfa-text-s'] = 0.85, ['pfa-text-normal'] = 1.0, ['pfa-text-l'] = 1.2,
  ['pfa-text-xl'] = 1.45, ['pfa-text-2xl'] = 1.7, ['pfa-text-3xl'] = 2.1,
}

local typst_align_dir = {
  ['pfa-align-center'] = 'center', ['pfa-align-left'] = 'left',
  ['pfa-align-right'] = 'right',  ['pfa-block-center'] = 'center',
  ['pfa-block-left'] = 'left',    ['pfa-block-right'] = 'right',
}

-- versalitas sinteticas: deja las mayusculas a tamano completo y reduce solo las
-- minusculas (pasadas a mayuscula). Self-contained, no depende de la plantilla.
local TYPST_SC_OPEN = '#{ set text(tracking: 0.04em); show regex("\\p{Ll}+"): it => text(size: 0.78em)[#upper(it)]; ['
local TYPST_SC_CLOSE = '] }'

-- familias: se completan en el hook Pandoc con los fonts del head.yaml
local typst_sans  = '"Liberation Sans", "DejaVu Sans", "Arial"'
local typst_serif = '"Liberation Serif", "DejaVu Serif", "Times New Roman"'
local typst_mono  = '"DejaVu Sans Mono", "Liberation Mono", "Courier New"'

-- open/close typst para una clase (sirve para Span y Div: typst envuelve
-- contenido inline y de bloque con la misma sintaxis de funcion)
local function typst_codes_for(class)
  class = pfa_canon[class] or class  -- resolver alias a su nombre canonico pfa-*
  if class == 'pfa-font-smallcaps' then return TYPST_SC_OPEN, TYPST_SC_CLOSE end
  if class == 'pfa-font-sans'  then return '#text(font: (' .. typst_sans  .. '))[', ']' end
  if class == 'pfa-font-serif' then return '#text(font: (' .. typst_serif .. '))[', ']' end
  if class == 'pfa-font-mono'  then return '#text(font: (' .. typst_mono  .. '))[', ']' end
  if typst_font_open[class] then return typst_font_open[class], ']' end
  if typst_size_em[class] then return '#text(size: ' .. typst_size_em[class] .. 'em)[', ']' end
  if typst_align_dir[class] then return '#align(' .. typst_align_dir[class] .. ')[', ']' end
  return nil
end

-- toda clase typst-manejable (para consumirlas y no re-envolver aguas abajo).
-- La alineacion solo aplica a Div (como en LaTeX).
local function typst_handles(class, tag)
  class = pfa_canon[class] or class  -- resolver alias a su nombre canonico pfa-*
  if class == 'pfa-font-smallcaps' or class == 'pfa-font-sans'
    or class == 'pfa-font-serif' or class == 'pfa-font-mono'
    or typst_font_open[class] ~= nil or typst_size_em[class] ~= nil then
    return true
  end
  return tag == 'Div' and typst_align_dir[class] ~= nil
end


-- ==============================================================================
-- SECTION 3: CORE LOGIC HANDLERS
-- ==============================================================================

-- Processes uppercase and lowercase transformations
local function apply_text_casing(elem, tag)
  local transform_func
  if elem.classes:includes('pfa-uppercase') then
    transform_func = function(s) return pandoc.Str(pandoc.text.upper(s.text)) end
  elseif elem.classes:includes('pfa-lowercase') then
    transform_func = function(s) return pandoc.Str(pandoc.text.lower(s.text)) end
  end

  if transform_func then
    return (tag == 'Div') and pandoc.walk_block(elem, { Str = transform_func }) or pandoc.walk_inline(elem, { Str = transform_func })
  end
  return elem
end

-- Translates all verified framework classes into format-specific structures
local function apply_standard_classes(elem, tag, raw, is_latex, is_typst)
  local code_for_class = latex_cmd_for_tags[tag]

  for i = #elem.classes, 1, -1 do
    local class_name = elem.classes[i]

    -- Set global injection flags if required functionality is detected
    if class_name:match('^pfa%-block%-') then uses_pfa_blocks = true end
    if latex_ulem_styles[class_name] then uses_ulem_styles = true end

    if latex_ulem_styles[class_name] then
      local ulem_code = latex_ulem_styles[class_name][1]
      -- Handle strikeout and underline directly through Pandoc native elements when possible
      if ulem_code == 'sout' then elem.content = List({ pandoc.Strikeout(elem.content) })
      elseif ulem_code == 'uline' then elem.content = List({ pandoc.Underline(elem.content) })
      elseif is_typst then
        -- typst solo trae underline/strike; las variantes (doble/punteado/onda)
        -- se aproximan con subrayado simple (nativo, sobrevive al writer)
        elem.content = List({ pandoc.Underline(elem.content) })
      elseif is_latex then
        -- Fall back to raw injection for advanced styles like wavy or dashed lines
        local new_content = List({ pandoc.RawInline('latex', '\\' .. ulem_code .. '{') })
        new_content:extend(elem.content)
        new_content:insert(pandoc.RawInline('latex', '}'))
        elem.content = new_content
      end
      -- panduck: clase consumida en typst (no debe re-envolverse aguas abajo)
      if is_typst then table.remove(elem.classes, i) end
    elseif is_typst and typst_handles(class_name, tag) then
      -- panduck: rama typst (pesos, estilo, tamanos, familias, versalitas, alineacion)
      local open, close = typst_codes_for(class_name)
      elem.content:insert(1, raw('typst', open))
      elem.content:insert(raw('typst', close))
      table.remove(elem.classes, i)  -- consumir la clase
    elseif is_latex and code_for_class[class_name] then
      local code = code_for_class[class_name]
      elem.content:insert(1, raw('latex', code[1]))
      if code[2] then elem.content:insert(raw('latex', code[2])) end
    elseif class_name:match('^pfa%-') and not known_pfa_classes[class_name] then
      io.stderr:write('[fonts-and-alignment] Warning: Unrecognized class "'
        .. class_name .. '" on <' .. tag .. '>\n')
    end
  end
  return elem
end


-- ==============================================================================
-- SECTION 4: COLOR HANDLING
-- ==============================================================================

-- Helper to resolve a single color atom (handles dictionary normalization & hex logic)
local function resolve_single_color(input)
  -- 1. Dictionary Check
  local clean_name = input:lower():gsub('[^%w]', '')
  if css_colors[clean_name] then
    local hex = css_colors[clean_name]
    -- Returns: HTML value, LaTeX value, is_latex_hex flag
    return '#' .. hex, hex, true
  end

  -- 2. Hex Check
  local raw_hex = input:gsub('^#', '')
  if raw_hex:match('^[0-9a-fA-F]+$') then
    if #raw_hex == 6 then
      return '#' .. raw_hex:upper(), raw_hex:upper(), true
    elseif #raw_hex == 3 then
      local r, g, b = raw_hex:sub(1,1), raw_hex:sub(2,2), raw_hex:sub(3,3)
      local full_hex = (r .. r .. g .. g .. b .. b):upper()
      return '#' .. full_hex, full_hex, true
    end
  end

  -- 3. Strict Pattern Validation (Fallback for raw LaTeX named colors)
  if input:match('^[a-zA-Z0-9%-]+$') then
    return input, input, false
  end

  return nil, nil, false
end

-- Safely resolves user-provided color strings, natively handling xcolor mixing!
local function resolve_color(input, is_latex)
  if not input then return nil, false end

  -- Detect xcolor mixing syntax (e.g., "maroon!30" or "red!50!black")
  if input:find('!') then
    local c1, pct, c2 = input:match('^([^!]+)!(%d+)!?([^!]*)$')
    if c1 and pct then
      -- LaTeX xcolor defaults to mixing with white if a second color isn't provided
      c2 = (c2 == '' or not c2) and 'white' or c2

      if is_latex then
        -- Pass the raw mix string directly to LaTeX
        return input, false
      else
        -- For HTML, resolve the individual components through the dictionary
        local css_c1 = resolve_single_color(c1)
        local css_c2 = resolve_single_color(c2)

        if css_c1 and css_c2 then
          -- Construct the native CSS translation
          local mix_string = string.format("color-mix(in srgb, %s %s%%, %s)", css_c1, pct, css_c2)
          return mix_string, false
        end
      end
    end
  end

  -- Handle Standard Single Colors
  local css_val, tex_val, is_hex = resolve_single_color(input)

  if not css_val then
    io.stderr:write('[fonts-and-alignment] Warning: Stripped invalid color pattern: "' .. input .. '"\n')
    return nil, false
  end

  if is_latex then
    return tex_val, is_hex
  else
    return css_val, false
  end
end

-- panduck: resuelve un color a hex "#RRGGBB" para typst. Soporta nombres CSS y
-- hex; en mezcla xcolor (rojo!50!negro) toma el primer color (typst no la tiene).
local function resolve_typst_hex(input)
  local first = input:find('!') and input:match('^([^!]+)') or input
  local css_val = resolve_single_color(first)  -- '#HEX' para nombre/hex, o el nombre crudo
  if css_val and css_val:sub(1, 1) == '#' then return css_val end
  return nil
end

-- Intercepts the pfa-font-color attribute, translates it, and removes the attribute
local function apply_color(elem, tag, raw, is_latex, is_typst)
  local color_attr = elem.attributes['pfa-font-color']
  if not color_attr then return elem end

  if is_typst then
    elem.attributes['pfa-font-color'] = nil
    local hex = resolve_typst_hex(color_attr)
    if not hex then return elem end
    elem.content:insert(1, raw('typst', '#text(fill: rgb("' .. hex .. '"))['))
    elem.content:insert(raw('typst', ']'))
    return elem
  end

  local resolved_val, is_hex = resolve_color(color_attr, is_latex)
  elem.attributes['pfa-font-color'] = nil -- Always clear the raw attribute

  if not resolved_val then return elem end -- Exit early if validation failed

  if is_latex then
    -- Apply specific xcolor formatting for LaTeX targets
    local fmt = is_hex and '[HTML]{' or '{'
    local begin_code = (tag == 'Span') and ('\\textcolor' .. fmt .. resolved_val .. '}{') or ('{\\color' .. fmt .. resolved_val .. '} ')
    elem.content:insert(1, raw('latex', begin_code))
    elem.content:insert(raw('latex', '}'))
  else
    -- Apply generic CSS style for HTML targets
    elem.attributes['style'] = (elem.attributes['style'] or '') .. 'color: ' .. resolved_val .. ';'
  end
  return elem
end


-- ==============================================================================
-- SECTION 5: MAIN EXECUTORS
-- ==============================================================================

-- Primary execution loop passed to Pandoc tree parsing
local function handler(elem)
  local tag = elem.tag
  local raw = raw_code_function[tag]
  local is_latex = FORMAT:match('latex') or FORMAT:match('beamer')
  local is_typst = FORMAT:match('typst') ~= nil  -- panduck

  elem = apply_text_casing(elem, tag)
  elem = apply_standard_classes(elem, tag, raw, is_latex, is_typst)
  -- Color must run last so \textcolor{...} wraps \uline / \sout / \uwave;
  elem = apply_color(elem, tag, raw, is_latex, is_typst)
  return elem
end

-- Handles automatic LaTeX package injection only if the features were used
local function meta_injector(meta)
  local is_latex = FORMAT:match('latex') or FORMAT:match('beamer')
  if not is_latex then return meta end

  local includes = meta['header-includes'] or List({})
  if type(includes) ~= 'table' then includes = List({ includes }) end

  if uses_pfa_blocks then
    local block_env_code = '\\usepackage{varwidth}\n' ..
      '\\newenvironment{pfa-block-center}{\\begin{center}\\begin{varwidth}{\\textwidth}}{\\end{varwidth}\\end{center}}\n' ..
      '\\newenvironment{pfa-block-left}{\\begin{flushleft}\\begin{varwidth}{\\textwidth}}{\\end{varwidth}\\end{flushleft}}\n' ..
      '\\newenvironment{pfa-block-right}{\\begin{flushright}\\begin{varwidth}{\\textwidth}}{\\end{varwidth}\\end{flushright}}'
    includes:insert(pandoc_lib.RawBlock('latex', block_env_code))
  end

  if uses_ulem_styles then
    includes:insert(pandoc_lib.RawBlock('latex', '\\usepackage[normalem]{ulem}'))
  end

  if #includes > 0 then meta['header-includes'] = includes end
  return meta
end


return {
  -- 1. Lifecycle hook
  {
    Pandoc = function(doc)
      uses_pfa_blocks = false
      uses_ulem_styles = false
      -- panduck: para typst, las familias sans/mono se resuelven con el nombre de
      -- fuente del head.yaml (typst no tiene cambio generico de familia). serif no
      -- tiene metadato y usa la lista de respaldo.
      if doc.meta.sansfont then typst_sans = '"' .. stringify(doc.meta.sansfont) .. '"' end
      if doc.meta.monofont then typst_mono = '"' .. stringify(doc.meta.monofont) .. '"' end
    end
  },
  -- 2. Core element processing layer
  { Div = handler, Span = handler },
  -- 3. Document header finalization
  { Meta = meta_injector }
}
