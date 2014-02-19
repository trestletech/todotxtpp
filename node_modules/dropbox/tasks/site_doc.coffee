fs = require 'fs'
mustache = require 'mustache'
path = require 'path'
S = require 'string'
yaml = require 'js-yaml'


# Converts codo YAML docs to the Dropbox site JSON format.
jsonDoc = (yamlDir, toc) ->
  classIndexPath = path.join yamlDir, 'class_index.yaml'
  index = yaml.load fs.readFileSync(classIndexPath, 'utf8')
  classes = index.classes

  classIndex = {}
  for klass in classes
    classPath = path.join yamlDir, klass.href
    klass.data = yaml.load fs.readFileSync(classPath, 'utf8')
    classIndex[klass.namespace + '.' + klass.name] = klass

  tocIndex = 0
  for section in toc.sections
    for entry in section.entries
      unless classIndex[entry.class]
        throw new Error "TOC entry not found: #{entry.class}"
      tocIndex += 1
      classIndex[entry.class].tocIndex = tocIndex

  inf = classes.length + 1
  classes.sort (a, b) ->
    if a.tocIndex or b.tocIndex
      (a.tocIndex or inf) - (b.tocIndex or inf)
    else if a.namespace is b.namespace
      a.name.localeCompare b.name
    else
      a.namespace.localeCompare b.namespace

  # Expand mixins.
  for klass in classes
    continue unless klass.data.includes
    for included in klass.data.includes
      includedMixin = classIndex[included.name]
      for method in includedMixin.data.methods
        continue if method.private
        methodClone = JSON.parse(JSON.stringify(method))
        methodClone.type = 'instance'
        klass.data.instanceMethods.push methodClone

  nameIndex = makeNameIndex classes

  json = { classes: [] }
  for klass in classes
    continue if klass.type is 'Mixin'

    jsonCMethods = []
    jsonIMethods = []
    jsonClass =
      name: klass.namespace + '.' + klass.name
      desc: xref(klass.data.doc.comment, nameIndex)
      sections: []
    json.classes.push jsonClass

    methodSections = [
      {
        methods: klass.data.classMethods, name: 'Class Methods',
        type: 'class'
      },
      {
        methods: klass.data.instanceMethods, name: 'Instance Methods',
        type: 'instance'
      }
    ]
    for section in methodSections
      continue unless section.methods and section.methods.length isnt 0
      jsonMethods = []
      jsonClass.sections.push(
          section_name: section.name, methods: jsonMethods)
      for method in section.methods
        jsonMethod =
          desc: ''
          method_name: method.name
          method_type: section.type
          discussion: xref(method.comment, nameIndex)
          formattedComponents: methodSignature(method, nameIndex)
          params: []
          option_hashes: []
          throws: []
          see: []
        jsonMethods.push jsonMethod

        if method.params and method.params.length isnt 0
          jsonMethod.has_params = true
          for param in method.params
            jsonParam =
              param_name: param.name
              formattedType: typeSignature(param.type, nameIndex)
              desc: xref(param.desc, nameIndex)
            jsonMethod.params.push jsonParam

        if method.options and method.options.length isnt 0
          for optionHash in method.options
            jsonOptions = []
            jsonHash =
              param_name: S(optionHash.hash).capitalize()
              options: jsonOptions
            jsonMethod.option_hashes.push jsonHash
            for option in optionHash.options
              jsonOption =
                option_name: option.name
                option_type: option.type
                desc: xref(option.desc, nameIndex)
              jsonOptions.push jsonOption

        if method.returns
          jsonMethod.returns = xref(method.returns.desc, nameIndex)

        if method.throws and method.throws.length isnt 0
          jsonMethod.has_throws = true
          for thrown in method.throws
            jsonThrown =
              formattedType: bareTypeSignature(thrown.type, nameIndex)
              desc: xref(thrown.desc, nameIndex)
            jsonMethod.throws.push jsonThrown

        if method.see and method.see.length isnt 0
          jsonMethod.has_see = true
          for see in method.see
            jsonSee =
              formattedType: seeAlsoReference(see, nameIndex)
              desc: ''
            jsonMethod.see.push jsonSee

    if klass.data.properties and klass.data.properties.length isnt 0
      jsonProperties = []
      jsonClass.sections.push(
          section_name: 'Properties', methods: jsonProperties)
      for property in klass.data.properties
        jsonProperty =
          desc: ''
          method_name: property.name
          method_type: 'property'
          discussion: xref(property.comment, nameIndex)
          formattedComponents: propertySignature(property, nameIndex)
          see: []
        jsonProperties.push jsonProperty

        if property.see and property.see.length isnt 0
          jsonProperty.has_see = true
          for see in property.see
            jsonSee =
              formattedType: seeAlsoReference(see, nameIndex)
              desc: ''
            jsonProperty.see.push jsonSee

    if klass.data.constants and klass.data.constants.length isnt 0
      jsonConstants = []
      jsonClass.sections.push(
          section_name: 'Constants', methods: jsonConstants)
      for constant in klass.data.constants
        jsonConstant =
          desc: ''
          method_name: constant.name
          method_type: 'constant'
          discussion: xref(constant.doc.comment, nameIndex)
          formattedComponents: constantSignature(constant, nameIndex)
          see: []
        jsonConstants.push jsonConstant

        if property.see and property.see.length isnt 0
          jsonConstant.has_see = true
          for see in property.see
            jsonSee =
              formattedType: seeAlsoReference(see, nameIndex)
              desc: ''
            jsonConstant.see.push jsonSee

  json


# Map from Codo references to href objects.
makeNameIndex = (classes) ->
  nameIndex = {}
  for klass in classes
    className = klass.namespace + '.' + klass.name
    nameIndex[className] = "##{className}"
    attrs = (klass.data?.instanceMethods or []).concat(
        klass.data?.properties or [])
    for attr in attrs
      nameIndex["#{className}##{attr.name}"] = "##{className}.#{attr.name}"

    cattrs = (klass.data?.classMethods or []).concat(
        klass.data?.constants or [])
    for attr in cattrs
      nameIndex["#{className}.#{attr.name}"] = "##{className}.#{attr.name}"
  nameIndex

# A method's signature, in the formattedComponents format used for iOS.
methodSignature = (method, nameIndex) ->
  formattedComponents = []

  if method.name isnt 'constructor'
    returnType = method.doc?.returns?.type or method.returns?.type or 'void'
    addTypeSignature returnType, nameIndex, formattedComponents
    formattedComponents.push value: ' '

  formattedComponents.push value: method.name, emphasized: true
  formattedComponents.push value: '('

  firstParam = true
  for param in method.params or []
    if firstParam
      firstParam = false
    else
      formattedComponents.push value: ', '
    formattedComponents.push value: param.name

  formattedComponents.push value: ')'
  formattedComponents


# A property's signature, in the formattedComponents format used for iOS.
propertySignature = (property, nameIndex) ->
  match = /\([^)]*\)/.exec property.signature
  if match
    propertyType = S(match[0]).unescapeHTML().
        replace(/(^\()|(\)$)/g, '').toString()
  else
    propertyType = null

  formattedComponents = []
  formattedComponents.push value: property.name, emphasized: true
  if propertyType
    formattedComponents.push value: ' '
    formattedComponents.push value: '('
    addTypeSignature propertyType, nameIndex, formattedComponents
    formattedComponents.push value: ')'
  formattedComponents

# A type's signature, in the formattedComponents format used for iOS.
typeSignature = (typeString, nameIndex) ->
  if typeString.length is 0
    null
  else
    formattedComponents = [{ value: '(' }]
    addTypeSignature typeString, nameIndex, formattedComponents
    formattedComponents.push value: ')'
  formattedComponents

# A type's signature, in the formattedComponents format, without parenthesis.
bareTypeSignature = (typeString, nameIndex) ->
  if typeString.length is 0
    null
  else
    addTypeSignature typeString, nameIndex, []

# Adds a type's signature to an in-construction formattedComponents array.
addTypeSignature = (typeString, nameIndex, formattedComponents) ->
  parts = typeString.split(/([\w\.\#]+)/)
  for part in parts
    continue if part.length is 0
    if nameIndex[part]
      formattedComponents.push value: part, href: nameIndex[part]
    else
      formattedComponents.push value: part
  formattedComponents

# A "See Also" reference, in the formattedComponents format used for iOS.
seeAlsoReference = (see, nameIndex) ->
  return null unless see.label
  if nameIndex[see.label]
    [{value: see.label, href: nameIndex[see.label]}]
  else
    [{value: see.label, href: see.reference}]


# Fixes <a> links in description text.
xref = (string, nameIndex) ->
  return string unless string

  string.replace /(<a [^>]*>)([^>]*)<\/a>/g, (match, tag, innerHtml) ->
    newHref = nameIndex[innerHtml.trim()]
    return match unless newHref
    newTag = tag.replace(/href='[^']+'/, "href='#{newHref}'")
    newTag = newTag.replace(/href="[^"]+"/, "href=\"#{newHref}\"")
    "#{newTag}#{innerHtml}</a>"


# A constant's signature, in the formattedComponents format used for iOS.
constantSignature = (constant) ->
  [{ value: constant.name }]


# Outputs
siteDoc = (siteDir) ->
  tocPath = path.join siteDir, 'templates', 'toc.json'
  toc = JSON.parse fs.readFileSync(tocPath, 'utf8')

  json = jsonDoc path.join(siteDir, 'yaml'), toc
  fs.writeFileSync path.join(siteDir, 'all.json'), JSON.stringify(json)

  htmlPath = path.join(siteDir, 'html')
  fs.mkdirSync htmlPath unless fs.existsSync htmlPath

  docsTemplatePath = path.join siteDir, 'templates', 'docs-template.html'
  docsTemplate = fs.readFileSync docsTemplatePath, 'utf8'
  docs = mustache.render docsTemplate, json, {}
  fs.writeFileSync path.join(htmlPath, 'docs_js_ds.html'), docs

  tocTemplatePath = path.join siteDir, 'templates', 'toc-template.html'
  tocTemplate = fs.readFileSync tocTemplatePath, 'utf8'
  toc = mustache.render tocTemplate, toc, {}
  fs.writeFileSync path.join(htmlPath, 'docs_js_ds_toc.html'), toc


module.exports = siteDoc
