import os  
import sys  
import fnmatch  
  
def extract_codebase_to_file(repo_path, output_file):  
    """  
    Extracts important text content from a codebase and saves it to a single file.  
      
    Args:  
        repo_path (str): Path to the repository root  
        output_file (str): Path to the output file  
    """  
    # File extensions to include  
    text_extensions = [  
        '.swift',                       # Swift files  
    ]  
      
    # Directories to exclude  
    exclude_dirs = [  
        'node_modules',  
        'dist',  
        'build',  
        'release',  
        '.git',  
    ]  
      
    # Files to exclude by pattern  
    exclude_patterns = [  
        '*.min.js',         # Minified JavaScript  
        '*.map',            # Source maps  
        'package-lock.json' # Large dependency lock file  
    ]  
      
    # Counter for stats  
    file_count = 0  
      
    with open(output_file, 'w', encoding='utf-8') as outfile:  
        # Write header  
        outfile.write(f"# Swift Codebase Extraction\n\n")  
        outfile.write(f"Repository path: {repo_path}\n")  
        outfile.write(f"Extraction date: {import_time().strftime('%Y-%m-%d %H:%M:%S')}\n\n")  
          
        # Walk through the directory structure  
        for root, dirs, files in os.walk(repo_path):  
            # Skip excluded directories  
            dirs[:] = [d for d in dirs if d not in exclude_dirs]  
              
            # Process files  
            for filename in files:  
                # Check if file has an included extension  
                if not any(filename.endswith(ext) for ext in text_extensions):  
                    continue  
                  
                # Skip excluded file patterns  
                if any(fnmatch.fnmatch(filename, pattern) for pattern in exclude_patterns):  
                    continue  
                  
                file_path = os.path.join(root, filename)  
                rel_path = os.path.relpath(file_path, repo_path)  
                  
                try:  
                    # Read file content  
                    with open(file_path, 'r', encoding='utf-8') as file:  
                        content = file.read()  
                      
                    # Write file header and content to output file  
                    outfile.write(f"\n\n{'=' * 80}\n")  
                    outfile.write(f"FILE: {rel_path}\n")  
                    outfile.write(f"{'=' * 80}\n\n")  
                    outfile.write(content)  
                      
                    file_count += 1  
                      
                except Exception as e:  
                    outfile.write(f"\n\nError reading {rel_path}: {str(e)}\n")  
          
        # Write summary  
        outfile.write(f"\n\n{'=' * 80}\n")  
        outfile.write(f"SUMMARY: Extracted {file_count} Swift files from the codebase.\n")  
  
def import_time():  
    """Import datetime module and return current time."""  
    from datetime import datetime  
    return datetime.now()  
  
if __name__ == "__main__":  
    # Check for command line arguments or use defaults  
    if len(sys.argv) > 1:  
        repo_path = sys.argv[1]  
    else:  
        repo_path = "/Users/raka/Desktop/WORK/PROJECTS/Prompt-you/Prompt-you/Prompt-you"  # Default repo path  
      
    if len(sys.argv) > 2:  
        output_file = sys.argv[2]  
    else:  
        output_file = "prompt_you_swift_extract.md"  
      
    extract_codebase_to_file(repo_path, output_file)  
    print(f"Extraction complete. Output written to {output_file}")
