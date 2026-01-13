# Cortex Skills Documentation

Welcome to the Cortex Skills documentation. This directory contains comprehensive guides, architecture decisions, and examples for using and contributing to Cortex Skills.

## 📚 Documentation Structure

### [Guides](./guides/)
How-to guides and tutorials for using Cortex Skills:
- Installation and setup
- Creating custom skills
- Publishing skills to the marketplace
- Using skill collections

### [Architecture](./architecture/)
Architecture decisions and design documents:
- Skill system architecture
- Marketplace plugin design
- Dependency management system

### [API](./api/)
API documentation and references:
- skill-config.schema.json reference
- Agent configuration API
- Marketplace integration API

### [Examples](./examples/)
Usage examples and sample implementations:
- Supabase integration examples
- GTM setup examples
- Lead scoring implementations
- Cross-repo examples (skills + packages)

### [Contributing](./contributing/)
Contributor guides and development docs:
- Contribution guidelines
- Development setup
- Testing skills locally
- Release process

## 🔗 Related Resources

- **Cortex Packages**: [github.com/antoineschaller/cortex-packages](https://github.com/antoineschaller/cortex-packages)
- **NPM Packages**: [@akson/cortex-* on npm](https://www.npmjs.com/search?q=%40akson%2Fcortex)
- **Compatibility Matrix**: [../COMPATIBILITY.md](../COMPATIBILITY.md)

## 📖 Quick Start

New to Cortex Skills? Start here:

1. **Installation**: Add the marketplace
   ```bash
   /plugin marketplace add https://github.com/antoineschaller/cortex-skills
   ```

2. **Install a Collection**: Pick a skill collection
   ```bash
   /plugin install ballee-skills@cortex-skills
   ```

3. **Use Skills**: Claude will automatically use skills when relevant context is detected

4. **Explore**: Browse the [skills/](../skills/) directory to see all available skills

## 🤝 Contributing

Want to contribute? Check out the [Contributing Guide](./contributing/) for:
- How to create a new skill
- Coding standards and patterns
- Pull request process
- Release and versioning

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/antoineschaller/cortex-skills/issues)
- **Discussions**: [GitHub Discussions](https://github.com/antoineschaller/cortex-skills/discussions)
