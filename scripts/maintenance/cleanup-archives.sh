#!/bin/bash
# Clean up deployment archives (optional)

echo "This will delete all tar.gz deployment archives."
echo "These files are safe to delete as they were temporary deployment packages."
echo ""
echo "Files to be deleted:"
ls -lah archives/deployment-history/*.tar.gz 2>/dev/null || echo "No tar.gz files found"
echo ""

read -p "Delete these archives? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f archives/deployment-history/*.tar.gz
    echo "✅ Archives cleaned up"
    echo "💾 Space freed: $(du -sh archives/deployment-history/ | cut -f1)"
else
    echo "❌ Cleanup cancelled"
fi
